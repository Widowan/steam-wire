------------
--- Misc ---
------------

local log = Log.open_topic("steam-wire")

function link_ports(input_port, output_port)
  log:trace(string.format("Linking ports %s and %s",
    tostring(input_port.properties["object.id"]), tostring(output_port.properties["object.id"])))

  if not input_port or not output_port then
    log:warning("nil values, not linking")
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

output_ports = Interest {
	type = "port",
	Constraint { "port.direction", "equals", "out" },
}

-----------
--- OMs ---
-----------

wine_om  = ObjectManager { apps_interest }
steam_om = ObjectManager { steam_interest }

-------------------
--- Connections ---
-------------------

-- On any steam node, ...
steam_om:connect("object-added", function(_, steam_node)
  log:trace("Steam object processing")
  -- ... We look for links with this node as one it is inputting into,
  steam_link_om = ObjectManager {
    Interest {
      type = "link",
      Constraint { "link.input.node", "equals", steam_node.properties["object.id"] },
    }
  }

  -- ... Then we look at the Audio/Sink nodes that are sources of this link,
  steam_link_om:connect("object-added", function(_, steam_link)
    log:trace("Processing steam link")
    steam_source_om = ObjectManager {
      Interest {
        type = "node",
        Constraint { "object.id", "equals", steam_link.properties["link.output.node"] },
        Constraint { "media.class", "matches", "Audio/Sink*" },
      }
    }

    -- ... And then we destroy them.
    steam_source_om:connect("object-added", function(_, source_node)
      log:trace("Processing link's source")
      local source_name = tostring(source_node.properties["node.name"])
      local source_desc = tostring(source_node.properties["node.description"])
      local source_id   = tostring(source_node.properties["object.id"])
      log:info(string.format("Disconnecting sink node %s [%s] (%s) from steam", source_name, source_desc, source_id))

      local _, err = pcall(function() steam_link:request_destroy() end)
      if err then log:debug("Destroying error: " .. tostring(err)) end
    end)

    steam_source_om:activate()
    log:trace("Activated steam_source_om")
  end)

  steam_link_om:activate()
  log:trace("Activated steam_link_om")
end)



-- For every wine app, ...
wine_om:connect("object-added", function(_, wine_node)
  log:trace("Wine object processing " .. tostring(wine_node.properties["object.id"]))
  local steam_count = steam_om:get_n_objects()
  if steam_count > 1 then
    log:warning("Found " .. steam_count .. " instances of steam input nodes! Wrong nodes may be connected.")
  end

  wine_port_om = ObjectManager {
    Interest {
      type = "port",
      Constraint { "node.id", "equals", wine_node.properties["object.id"] },
      Constraint { "port.direction", "equals", "out" },
    }
  }

  -- ... We're waiting for it to have ports (which can very
  -- much be not instant, look at spotify and FFXIV), ...
  wine_port_om:connect("object-added", function(_, wine_port)
    log:trace("Added wine port " .. tostring(wine_port.properties["object.id"]))

    -- ..., Comparing them to steam's ports, ...
    for steam_node in steam_om:iterate() do
      log:trace("Processing steam node " .. tostring(steam_node.properties["object.id"]))

      for steam_port in steam_node:iterate_ports(input_ports) do
        log:trace("Processing steam port " .. tostring(steam_port.properties["object.id"]))

        -- ..., Checking if those ports match channels, ...
        if steam_port.properties["audio.channel"] == wine_port.properties["audio.channel"] then
          log:trace("Found steam port and wine port with matching channels")

          local name = tostring(wine_node.properties["node.name"])
          local id   = tostring(wine_node.properties["object.id"])
          log:info(string.format("Linking ports of node \"%s\" (%s) with steam", name, id))

          -- ... And connect them.
          link_ports(steam_port, wine_port)
        end
      end
    end
  end)

  wine_port_om:activate()
  log:trace("Activating wine_port_om")
end)


steam_om:activate()
wine_om:activate()
