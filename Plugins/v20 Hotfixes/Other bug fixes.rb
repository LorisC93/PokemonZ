#===============================================================================
# "v20 Hotfixes" plugin
# This file contains fixes for bugs in Essentials v20.
# These bug fixes are also in the master branch of the GitHub version of
# Essentials:
# https://github.com/Maruno17/pokemon-essentials
#===============================================================================

Essentials::ERROR_TEXT += "[v20 Hotfixes 1.0.2]\r\n"

#===============================================================================
# Fixed event evolutions not working.
#===============================================================================
class Pokemon
  def check_evolution_by_event(value = 0)
    return check_evolution_internal { |pkmn, new_species, method, parameter|
      success = GameData::Evolution.get(method).call_event(pkmn, parameter, value)
      next (success) ? new_species : nil
    }
  end
end

#===============================================================================
# Fixed not registering a gifted Pokémon as seen/owned before looking at its
# Pokédex entry.
#===============================================================================
def pbAddPokemon(pkmn, level = 1, see_form = true)
  return false if !pkmn
  if pbBoxesFull?
    pbMessage(_INTL("There's no more room for Pokémon!\1"))
    pbMessage(_INTL("The Pokémon Boxes are full and can't accept any more!"))
    return false
  end
  pkmn = Pokemon.new(pkmn, level) if !pkmn.is_a?(Pokemon)
  species_name = pkmn.speciesName
  pbMessage(_INTL("{1} obtained {2}!\\me[Pkmn get]\\wtnp[80]\1", $player.name, species_name))
  was_owned = $player.owned?(pkmn.species)
  $player.pokedex.set_seen(pkmn.species)
  $player.pokedex.set_owned(pkmn.species)
  $player.pokedex.register(pkmn) if see_form
  # Show Pokédex entry for new species if it hasn't been owned before
  if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && see_form && !was_owned && $player.has_pokedex
    pbMessage(_INTL("{1}'s data was added to the Pokédex.", species_name))
    $player.pokedex.register_last_seen(pkmn)
    pbFadeOutIn {
      scene = PokemonPokedexInfo_Scene.new
      screen = PokemonPokedexInfoScreen.new(scene)
      screen.pbDexEntry(pkmn.species)
    }
  end
  # Nickname and add the Pokémon
  pbNicknameAndStore(pkmn)
  return true
end

def pbAddPokemonSilent(pkmn, level = 1, see_form = true)
  return false if !pkmn || pbBoxesFull?
  pkmn = Pokemon.new(pkmn, level) if !pkmn.is_a?(Pokemon)
  $player.pokedex.set_seen(pkmn.species)
  $player.pokedex.set_owned(pkmn.species)
  $player.pokedex.register(pkmn) if see_form
  pkmn.record_first_moves
  if $player.party_full?
    $PokemonStorage.pbStoreCaught(pkmn)
  else
    $player.party[$player.party.length] = pkmn
  end
  return true
end

def pbAddToParty(pkmn, level = 1, see_form = true)
  return false if !pkmn || $player.party_full?
  pkmn = Pokemon.new(pkmn, level) if !pkmn.is_a?(Pokemon)
  species_name = pkmn.speciesName
  pbMessage(_INTL("{1} obtained {2}!\\me[Pkmn get]\\wtnp[80]\1", $player.name, species_name))
  was_owned = $player.owned?(pkmn.species)
  $player.pokedex.set_seen(pkmn.species)
  $player.pokedex.set_owned(pkmn.species)
  $player.pokedex.register(pkmn) if see_form
  # Show Pokédex entry for new species if it hasn't been owned before
  if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && see_form && !was_owned && $player.has_pokedex
    pbMessage(_INTL("{1}'s data was added to the Pokédex.", species_name))
    $player.pokedex.register_last_seen(pkmn)
    pbFadeOutIn {
      scene = PokemonPokedexInfo_Scene.new
      screen = PokemonPokedexInfoScreen.new(scene)
      screen.pbDexEntry(pkmn.species)
    }
  end
  # Nickname and add the Pokémon
  pbNicknameAndStore(pkmn)
  return true
end

def pbAddForeignPokemon(pkmn, level = 1, owner_name = nil, nickname = nil, owner_gender = 0, see_form = true)
  return false if !pkmn || $player.party_full?
  pkmn = Pokemon.new(pkmn, level) if !pkmn.is_a?(Pokemon)
  pkmn.owner = Pokemon::Owner.new_foreign(owner_name || "", owner_gender)
  pkmn.name = nickname[0, Pokemon::MAX_NAME_SIZE] if !nil_or_empty?(nickname)
  pkmn.calc_stats
  if owner_name
    pbMessage(_INTL("\\me[Pkmn get]{1} received a Pokémon from {2}.\1", $player.name, owner_name))
  else
    pbMessage(_INTL("\\me[Pkmn get]{1} received a Pokémon.\1", $player.name))
  end
  was_owned = $player.owned?(pkmn.species)
  $player.pokedex.set_seen(pkmn.species)
  $player.pokedex.set_owned(pkmn.species)
  $player.pokedex.register(pkmn) if see_form
  # Show Pokédex entry for new species if it hasn't been owned before
  if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && see_form && !was_owned && $player.has_pokedex
    pbMessage(_INTL("The Pokémon's data was added to the Pokédex."))
    $player.pokedex.register_last_seen(pkmn)
    pbFadeOutIn {
      scene = PokemonPokedexInfo_Scene.new
      screen = PokemonPokedexInfoScreen.new(scene)
      screen.pbDexEntry(pkmn.species)
    }
  end
  # Add the Pokémon
  pbStorePokemon(pkmn)
  return true
end

#===============================================================================
# Fixed the player animating super-fast for a while after surfing.
#===============================================================================
class Game_Player < Game_Character
  alias __hotfixes_update_pattern update_pattern
  def update_pattern
    __hotfixes_update_pattern
    @anime_count = 0 if $PokemonGlobal&.surfing || $PokemonGlobal&.diving
  end
end

#===============================================================================
# Fixed error when using Rotom Catalog.
#===============================================================================
ItemHandlers::UseOnPokemon.add(:ROTOMCATALOG, proc { |item, qty, pkmn, scene|
  if !pkmn.isSpecies?(:ROTOM)
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  elsif pkmn.fainted?
    scene.pbDisplay(_INTL("This can't be used on the fainted Pokémon."))
    next false
  end
  choices = [
    _INTL("Light bulb"),
    _INTL("Microwave oven"),
    _INTL("Washing machine"),
    _INTL("Refrigerator"),
    _INTL("Electric fan"),
    _INTL("Lawn mower"),
    _INTL("Cancel")
  ]
  new_form = scene.pbShowCommands(_INTL("Which appliance would you like to order?"),
     choices, pkmn.form)
  if new_form == pkmn.form
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  elsif new_form > 0 && new_form < choices.length - 1
    pkmn.setForm(new_form) {
      scene.pbRefresh
      scene.pbDisplay(_INTL("{1} transformed!", pkmn.name))
    }
    next true
  end
  next false
})

#===============================================================================
# Fixed Pickup's out-of-battle effect causing an error.
#===============================================================================
def pbPickup(pkmn)
  return if pkmn.egg? || !pkmn.hasAbility?(:PICKUP)
  return if pkmn.hasItem?
  return unless rand(100) < 10   # 10% chance for Pickup to trigger
  num_rarity_levels = 10
  # Ensure common and rare item lists contain defined items
  common_items = pbDynamicItemList(*PICKUP_COMMON_ITEMS)
  rare_items = pbDynamicItemList(*PICKUP_RARE_ITEMS)
  return if common_items.length < num_rarity_levels - 1 + PICKUP_COMMON_ITEM_CHANCES.length
  return if rare_items.length < num_rarity_levels - 1 + PICKUP_RARE_ITEM_CHANCES.length
  # Determine the starting point for adding items from the above arrays into the
  # pool
  start_index = [([100, pkmn.level].min - 1) * num_rarity_levels / 100, 0].max
  # Generate a pool of items depending on the Pokémon's level
  items = []
  PICKUP_COMMON_ITEM_CHANCES.length.times { |i| items.push(common_items[start_index + i]) }
  PICKUP_RARE_ITEM_CHANCES.length.times { |i| items.push(rare_items[start_index + i]) }
  # Randomly choose an item from the pool to give to the Pokémon
  all_chances = PICKUP_COMMON_ITEM_CHANCES + PICKUP_RARE_ITEM_CHANCES
  rnd = rand(all_chances.sum)
  cumul = 0
  all_chances.each_with_index do |c, i|
    cumul += c
    next if rnd >= cumul
    pkmn.item = items[i]
    break
  end
end

#===============================================================================
# Fixed some Battle Challenge code not recognising a valid team if a team size
# limit is imposed.
#===============================================================================
class PokemonRuleSet
  def canRegisterTeam?(team)
    return false if !team || team.length < self.minTeamLength
    return false if team.length > self.maxTeamLength
    teamNumber = self.minTeamLength
    team.each do |pkmn|
      return false if !isPokemonValid?(pkmn)
    end
    @teamRules.each do |rule|
      return false if !rule.isValid?(team)
    end
    if @subsetRules.length > 0
      pbEachCombination(team, teamNumber) { |comb|
        isValid = true
        @subsetRules.each do |rule|
          next if rule.isValid?(comb)
          isValid = false
          break
        end
        return true if isValid
      }
      return false
    end
    return true
  end

  def hasValidTeam?(team)
    return false if !team || team.length < self.minTeamLength
    teamNumber = self.minTeamLength
    validPokemon = []
    team.each do |pkmn|
      validPokemon.push(pkmn) if isPokemonValid?(pkmn)
    end
    return false if validPokemon.length < teamNumber
    if @teamRules.length > 0
      pbEachCombination(team, teamNumber) { |comb| return true if isValid?(comb) }
      return false
    end
    return true
  end
end
