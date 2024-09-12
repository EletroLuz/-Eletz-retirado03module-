local object_interaction = {}

-- Define padrões para nomes de objetos interativos e seus custos em cinders
local interactive_patterns = {
    usz_rewardGizmo_1H = 125,
    usz_rewardGizmo_2H = 125,
    usz_rewardGizmo_ChestArmor = 75,
    usz_rewardGizmo_Rings = 125,
    usz_rewardGizmo_infernalsteel = 175,
    usz_rewardGizmo_Uber = 175,
    usz_rewardGizmo_Amulet = 125,
    usz_rewardGizmo_Gloves = 75,
    usz_rewardGizmo_Legs = 75,
    usz_rewardGizmo_Boots = 75,
    usz_rewardGizmo_Helm = 75,
}

-- Tabela para armazenar objetos já interagidos (blacklist)
local interacted_objects = {}

-- Variável para controlar o tempo da última interação
local last_interaction_time = 0
local PAUSE_DURATION = 5 -- 5 segundos de pausa

-- Nova tabela com os padrões de nomes dos itens válidos que podem ser dropados do baú
local valid_chest_loot = {
    "helm",
    "chest",
    "gloves",
    "pants",
    "boots",
    "sword",
    "amulet",
    "ring",
    "InfernalSteel"
}

-- Função auxiliar para verificar se um item é um loot válido do baú
local function is_valid_chest_loot(item_name)
    item_name = item_name:lower()
    for _, loot_type in ipairs(valid_chest_loot) do
        if item_name:find(loot_type:lower()) then
            return true
        end
    end
    return false
end

-- Função para verificar se o objeto atende aos critérios de interação
function object_interaction.check_interaction_criteria(object_name)
    local cinders_needed = interactive_patterns[object_name]
    if not cinders_needed then
        return false
    end

    local current_cinders = get_helltide_coin_cinders()
    return current_cinders >= cinders_needed
end

-- Função para mover até o objeto e interagir
function object_interaction.move_and_interact(object)
    local player_pos = get_player_position()
    local obj_pos = object:get_position()
    
    if player_pos:dist_to(obj_pos) > 2 then
        pathfinder.request_move(obj_pos)
        return false -- Ainda não chegou ao objeto
    else
        interact_object(object)
        last_interaction_time = os.clock()
        console.print("Interação iniciada. Pausando movimento por 5 segundos.")
        return true -- Interagiu com o objeto
    end
end

-- Função para verificar o sucesso da interação
function object_interaction.verify_interaction_success(initial_cinders, start_time)
    local current_time = os.clock()
    local max_wait_time = 5  -- Espera no máximo 5 segundos

    if current_time - start_time > max_wait_time then
        return false -- Tempo máximo excedido
    end

    local current_cinders = get_helltide_coin_cinders()
    local ground_items = actors_manager.get_all_items()

    if current_cinders < initial_cinders and #ground_items > 0 then
        -- Verifica se algum dos itens no chão é um loot válido do baú
        for _, item in ipairs(ground_items) do
            local item_name = item:get_name() -- Assumindo que existe um método get_name()
            if is_valid_chest_loot(item_name) then
                console.print("Item válido encontrado: " .. item_name)
                return true
            end
        end
        console.print("Nenhum item válido encontrado entre os itens dropados.")
        return false
    end

    return nil -- Continua verificando
end

-- Função principal para interagir com o objeto
function object_interaction.interact_with_object(object)
    local object_name = object:get_skin_name()
    local object_position = object:get_position()

    -- Verifica se o objeto já foi interagido
    for _, interacted_obj in ipairs(interacted_objects) do
        if interacted_obj.position:dist_to(object_position) < 1 then
            return false
        end
    end

    -- Verifica os critérios de interação
    if not object_interaction.check_interaction_criteria(object_name) then
        console.print("Cinders insuficientes para interagir com " .. object_name)
        return false
    end

    local max_attempts = 3
    local attempt = 0
    local interaction_state = "move"
    local interaction_start_time
    local initial_cinders

    return function()
        if attempt >= max_attempts then
            console.print("Falha na interação com " .. object_name .. " após " .. max_attempts .. " tentativas.")
            return true -- Interação concluída (com falha)
        end

        if interaction_state == "move" then
            if object_interaction.move_and_interact(object) then
                interaction_state = "verify"
                interaction_start_time = os.clock()
                initial_cinders = get_helltide_coin_cinders()
                attempt = attempt + 1
                console.print("Tentativa " .. attempt .. " de interagir com " .. object_name)
            end
        elseif interaction_state == "verify" then
            local result = object_interaction.verify_interaction_success(initial_cinders, interaction_start_time)
            if result == true then
                -- Interação bem-sucedida
                table.insert(interacted_objects, {name = object_name, position = object_position})
                console.print("Interação bem-sucedida com " .. object_name)
                return true -- Interação concluída (com sucesso)
            elseif result == false then
                -- Falha na interação, tenta novamente
                interaction_state = "move"
            end
        end

        return false -- Interação ainda em andamento
    end
end

-- Função de atualização
function object_interaction.update()
    if object_interaction.is_interacting() then
        return
    end

    local objects = actors_manager.get_ally_actors()
    for _, obj in ipairs(objects) do
        if obj and object_interaction.check_interaction_criteria(obj:get_skin_name()) then
            local interaction_coroutine = object_interaction.interact_with_object(obj)
            
            local start_time = os.clock()
            while not interaction_coroutine() do
                if os.clock() - start_time > 0.1 then
                    break -- Sai do loop após 0.1 segundos
                end
            end

            break
        end
    end
end

-- Função para limpar a blacklist quando a Helltide acabar
function object_interaction.clear_blacklist()
    interacted_objects = {}
end

-- Função para verificar se uma interação está em andamento
function object_interaction.is_interacting()
    return os.clock() - last_interaction_time < PAUSE_DURATION
end

return object_interaction