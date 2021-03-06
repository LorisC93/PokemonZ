#===============================================================================
# Automatic Level Scaling
# By Benitex
#===============================================================================

EventHandlers.add(:on_wild_pokemon_created, :automatic_level_scaling,
  proc { |pokemon|
    id = $game_variables[LevelScalingSettings::WILD_VARIABLE]
    if id != 0
      AutomaticLevelScaling.setDifficulty(id)
      AutomaticLevelScaling.setNewLevel(pokemon)
    end
  }
)

EventHandlers.add(:on_trainer_load, :automatic_level_scaling,
  proc { |trainer|
    id = $game_variables[LevelScalingSettings::TRAINER_VARIABLE]
    if trainer && id != 0
      AutomaticLevelScaling.setDifficulty(id)
      avarage_level = 0
      trainer.party.each { |pokemon| avarage_level += pokemon.level }
      avarage_level /= trainer.party.length

      for pokemon in trainer.party
        AutomaticLevelScaling.setNewLevel(pokemon, pokemon.level - avarage_level)
      end
    end
  }
)

class AutomaticLevelScaling
  @@selectedDifficulty = Difficulty.new(id: 0)
  @@settings = {
    automatic_evolutions: LevelScalingSettings::AUTOMATIC_EVOLUTIONS,
    first_evolution_level: LevelScalingSettings::DEFAULT_FIRST_EVOLUTION_LEVEL,
    second_evolution_level: LevelScalingSettings::DEFAULT_SECOND_EVOLUTION_LEVEL,
    proportional_scaling: LevelScalingSettings::PROPORTIONAL_SCALING,
    update_moves: true
  }

  def self.setDifficulty(id)
    for difficulty in LevelScalingSettings::DIFICULTIES do
      @@selectedDifficulty = difficulty if difficulty.id == id
    end
  end

  def self.setSettings(update_moves: true, automatic_evolutions: LevelScalingSettings::AUTOMATIC_EVOLUTIONS, proportional_scaling: LevelScalingSettings::PROPORTIONAL_SCALING, first_evolution_level: LevelScalingSettings::DEFAULT_FIRST_EVOLUTION_LEVEL, second_evolution_level: LevelScalingSettings::DEFAULT_SECOND_EVOLUTION_LEVEL)
    @@settings[:update_moves] = update_moves
    @@settings[:first_evolution_level] = first_evolution_level
    @@settings[:second_evolution_level] = second_evolution_level
    @@settings[:proportional_scaling] = proportional_scaling
    @@settings[:automatic_evolutions] = automatic_evolutions
  end

  def self.setNewLevel(pokemon, difference_from_average = 0)
    new_level = pbBalancedLevel($player.party) - 2 # pbBalancedLevel increses level by 2 to challenge the player

    # Difficulty modifiers
    new_level += @@selectedDifficulty.fixed_increase
    if @@selectedDifficulty.random_increase < 0
      new_level += rand(@@selectedDifficulty.random_increase..0)
    elsif @@selectedDifficulty.random_increase > 0
      new_level += rand(@@selectedDifficulty.random_increase)
    end
    # Proportional scaling
    new_level += difference_from_average if @@settings[:proportional_scaling]

    new_level = new_level.clamp(1, GameData::GrowthRate.max_level)
    pokemon.level = new_level

    # Evolution part
    AutomaticLevelScaling.setNewStage(pokemon) if @@settings[:automatic_evolutions]

    pokemon.calc_stats
    pokemon.reset_moves if @@settings[:update_moves]
  end

  def self.setNewStage(pokemon)
    pokemon.species = GameData::Species.get(pokemon.species).get_baby_species # revert to the first stage

    2.times do |evolvedTimes|
      evolutions = GameData::Species.get(pokemon.species).get_evolutions(false)

      # Checks if the species only evolve by level up
      other_evolving_method = false
      evolutions.length.times { |i|
        if evolutions[i][1] != :Level
          other_evolving_method = true
        end
      }

      if !other_evolving_method   # Species that evolve by level up
        if pokemon.check_evolution_on_level_up != nil
          pokemon.species = pokemon.check_evolution_on_level_up
        end

      else  # For species with other evolving methods
        # Checks if the pokemon is in it's midform and defines the level to evolve
        level = evolvedTimes == 0 ? @@settings[:first_evolution_level] : @@settings[:second_evolution_level]

        if pokemon.level >= level
          if evolutions.length == 1     # Species with only one possible evolution
            pokemon.species = evolutions[0][0]
          elsif evolutions.length > 1   # Species with multiple possible evolutions (the evolution is randomly defined)
            pokemon.species = evolutions[rand(0, evolutions.length - 1)][0]
          end
        end
      end
    end
  end
end
