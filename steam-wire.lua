------------
--- Misc ---
------------
local log = Log.open_topic("steam-wire")

function link_ports(input_port, output_port)
  log:trace("Linking ports " .. dump_port(input_port) .. " and " .. dump_port(output_port))

  if not input_port or not output_port then
    log:warning("One of the ports is nil, won't link")
    return
  end

  local link_args = {
    ["link.input.node"]  = input_port.properties["node.id"],
    ["link.input.port"]  = input_port.properties["object.id"],
    ["link.output.node"] = output_port.properties["node.id"],
    ["link.output.port"] = output_port.properties["object.id"],
    ["object.id"]        = nil,
    ["object.linger"]    = true,
    ["node.description"] = "Link created by steam-wire",
  }

  local link = Link("link-factory", link_args)
  link:activate(1)
end

function destroy_link(link)
  log:trace("Destroying link " .. dump_link(link))

  local _, err = pcall(function() link:request_destroy() end)
  if err then log:debug("Link " .. dump_link(link) ".. destruction error error: " .. tostring(err)) end
  return err
end



-------------
--- Debug ---
-------------

function dump_link(link)
  local id          = link.properties["object.id"]
  local source_node = link.properties["link.input.node"]
  local source_port = link.properties["link.input.port"]
  local target_node = link.properties["link.output.node"]
  local target_port = link.properties["link.output.port"]
  return string.format("Link(Id=%s, Nodes=%s->%s, Ports=%s->%s)",
      id, source_node, target_node, source_port, target_port)
end

function dump_port(port)
  local id        = port.properties["object.id"]
  local alias     = port.properties["port.alias"]
  local channel   = port.properties["audio.channel"]
  local direction = port.properties["port.direction"]
  local node_id   = port.properties["node.id"]
  return string.format("Port(Id=%s, Dir=%s, Channel=%s, Node=%s, Alias=%s)",
      id, direction, channel, node_id, alias)
end

function dump_node(node)
  local name    = node.properties["application.name"] or node.properties["node.name"]
  local binary  = node.properties["application.process.binary"]
  local class   = node.properties["media.class"]
  local id      = node.properties["object.id"]
  return string.format("Node(Id=%s, Class=%s, Binary=%s, Name=%s)",
        id, class, binary, name)
end



-----------------
--- Interests ---
-----------------

steam_interest = Interest {
  type = "node",
  Constraint { "application.process.binary", "matches", "steam",              type = "pw" },
  Constraint { "media.class",                "matches", "Stream/Input/Audio", type = "pw" },
}

apps_interest = Interest {
  type = "node",
  Constraint { "application.process.binary", "matches", "wine64-preloader",    type = "pw" },
  Constraint { "media.class",                "matches", "Stream/Output/Audio", type = "pw" },
}

input_ports = Interest {
  type = "port",
  Constraint { "port.direction", "equals", "in" },
}


-----------
--- OMs ---
-----------

wine_om  = ObjectManager { apps_interest }
steam_om = ObjectManager { steam_interest }



-------------------------
--- Steam Connections ---
-------------------------
function process_steam_link(steam_link)
  log:trace("Processing steam link " .. dump_link(steam_link))

  steam_source_node_om = ObjectManager {
    Interest {
      type = "node",
      Constraint { "object.id", "equals", steam_link.properties["link.output.node"] },
      Constraint { "media.class", "matches", "Audio/Sink*" },
    }
  }

  steam_source_node_om:connect("object-added", function(_, source_node)
    log:info("Disconnecting node " .. dump_node(source_node) .. " from steam")
    destroy_link(steam_link)
  end)

  steam_source_node_om:activate()
end



function process_steam_node(steam_node)
  log:trace("Processing steam node " .. dump_node(steam_node))

  steam_link_om = ObjectManager {
    Interest {
      type = "link",
      Constraint { "link.input.node", "equals", steam_node.properties["object.id"] },
    }
  }

  steam_link_om:connect("object-added", function(_, steam_link)
    process_steam_link(steam_link)
  end)

  steam_link_om:activate()
end



------------------------
--- Wine connections ---
------------------------
function wine_link_matching_steam_ports(wine_port, steam_node)
  log:trace(string.format("Checking compatibility of wine port %s with steam node %s",
      dump_port(wine_port), dump_node(steam_node)))

  for steam_port in steam_node:iterate_ports(input_ports) do
    log:trace(string.format("Checking compatibility of wine port %s with steam port %s",
        dump_port(wine_port), dump_port(steam_port)))

    if steam_port.properties["audio.channel"] == wine_port.properties["audio.channel"] then
      log:info(string.format("Linking port %s with steam node %s", dump_port(wine_port), dump_port(steam_node)))
      link_ports(steam_port, wine_port)
    end
  end
end



function process_wine_node(wine_node)
  log:trace("Processing wine node " .. dump_node(wine_node))

  if steam_om:get_n_objects() > 1 then
    log:warning("Multiple instances of Steam nodes found, expect weird behavior")
  end

  for steam_node in steam_om:iterate() do
    process_steam_node(steam_node)
  end

  wine_port_om = ObjectManager {
    Interest {
      type = "port",
      Constraint { "node.id", "equals", wine_node.properties["object.id"] },
      Constraint { "port.direction", "equals", "out" },
    }
  }

  wine_port_om:connect("object-added", function(_, wine_port)
    for steam_node in steam_om:iterate() do
      wine_link_matching_steam_ports(wine_port, steam_node)
    end
  end)

  wine_port_om:activate()
end


------------
--- Main ---
------------


wine_om:connect("object-added", function(_, wine_node)
  process_wine_node(wine_node)
end)

steam_om:activate()
wine_om:activate()
