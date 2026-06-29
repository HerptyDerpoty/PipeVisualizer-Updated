local renderer = require("scripts.renderer")

--- @class EntityData
--- @field connections table<FluidSystemID, PipeConnectionExt[]>
--- @field connection_objects table<FluidSystemID, LuaRenderObject[]>
--- @field shape LuaRenderObject?
--- @field mapshape LuaRenderObject?
--- @field entity LuaEntity
--- @field unit_number UnitNumber

--- @class PipeConnectionExt: PipeConnection
--- @field direction defines.direction
--- @field shape_position MapPosition
--- @field target_owner LuaEntity?

--- @param from MapPosition
--- @param to MapPosition
--- @return defines.direction
local function get_cardinal_direction(from, to)
  local dx = to.x - from.x
  local dy = to.y - from.y

  if math.abs(dx) > math.abs(dy) then
    if dx > 0 then
      return defines.direction.east
    end
    return defines.direction.west
  end

  if dy > 0 then
    return defines.direction.south
  end

  return defines.direction.north
end

--- @class EntityDataModule
local entity_data = {}

--- @param entity LuaEntity
--- @param fluidbox_index uint
--- @param connections PipeConnectionExt[]
--- @return FluidSystemID | "none"
local function get_fluid_system_id(entity, fluidbox_index, connections)
  if entity.has_fluid_segment(fluidbox_index) then
    return entity.get_fluid_segment_id(fluidbox_index)
  end

  for _, connection in pairs(connections) do
    local target = connection.target
    local target_fluidbox_index = connection.target_fluidbox_index
    if target and target_fluidbox_index and target.valid and target.has_fluid_segment(target_fluidbox_index) then
      return target.get_fluid_segment_id(target_fluidbox_index)
    end
  end

  return "none"
end

--- @param iterator Iterator
--- @param entity LuaEntity
--- @return EntityData?
function entity_data.create(iterator, entity)
  local unit_number = entity.unit_number
  if not unit_number then
    return
  end

  local data = iterator.entities[unit_number]
  if data then
    -- ---@diagnostic disable-next-line: missing-fields
    -- entity.surface.create_entity({
    --   name = "flying-text",
    --   text = "Redraw",
    --   color = { r = 1, g = 0.3, b = 0.3 },
    --   position = entity.position,
    -- })
    entity_data.remove(iterator, data)
  end

  --- @type EntityData
  local data = {
    connection_objects = {},
    connections = {},
    entity = entity,
    unit_number = unit_number,
  }

  for i = 1, entity.fluids_count do
    --- @cast i uint
    local connections = entity.get_fluid_box_pipe_connections(i) or {}
    --- @cast connections PipeConnectionExt[]
    local id = get_fluid_system_id(entity, i, connections)
    for _, connection in pairs(connections) do
      connection.shape_position = {
        x = connection.position.x + (connection.target_position.x - connection.position.x) / 2,
        y = connection.position.y + (connection.target_position.y - connection.position.y) / 2,
      }
      connection.direction = get_cardinal_direction(connection.position, connection.target_position)
      if connection.target then
        connection.target_owner = connection.target
      end
    end
    local existing_connections = data.connections[id]
    if existing_connections then
      for _, connection in pairs(connections) do
        existing_connections[#existing_connections + 1] = connection
      end
    else
      data.connections[id] = connections
    end
  end

  iterator.entities[unit_number] = data
  return data
end

--- @param iterator Iterator
--- @param data EntityData
function entity_data.remove(iterator, data)
  renderer.clear(data)
  iterator.entities[data.unit_number] = nil
end

--- @param iterator Iterator
--- @param data EntityData
--- @param fluid_system_id FluidSystemID | "none"
function entity_data.remove_system(iterator, data, fluid_system_id)
  if renderer.clear_system(iterator, data, fluid_system_id) then
    iterator.entities[data.unit_number] = nil
  end
end

--- @param iterator Iterator
--- @param entity LuaEntity
--- @return EntityData?
function entity_data.get(iterator, entity)
  local unit_number = entity.unit_number
  if not unit_number then
    return
  end
  return iterator.entities[unit_number]
end

--- @param iterator Iterator
--- @param entity LuaEntity
--- @return EntityData?
function entity_data.get_or_create(iterator, entity)
  local data = entity_data.get(iterator, entity)
  if data then
    return data
  end
  return entity_data.create(iterator, entity)
end

return entity_data
