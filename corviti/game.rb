
# game.rb
require_relative 'character.rb'
require_relative 'location.rb'

# Assuming Character, Player, and NPC classes are defined as mentioned before

def game_loop(player, npc)
    loop do
      puts "\nWhat will you do? (flee, attack, speak)"
      choice = gets.chomp.downcase
      case choice
      when "flee"
        puts "You have chosen to flee. The adventure ends here."
        break
      when "attack"
        player.attack(npc)
        if npc.health <= 0
            puts "#{npc.name} has been defeated!"
            player.gain_feat("Power Strike") # Example feat
            player.increase_stat
            skill_based_actions(player) # Transition to skill-based actions after combat
        end
        npc.attack(player)
        if player.health <= 0
          puts "You have been defeated. Game over."
          break
        end
      when "speak"
        player.speak
        npc.speak
      else
        puts "Invalid choice. Choose flee, attack, or speak."
      end
    end
  end
  

  def skill_based_actions(player)
    loop do
      puts "\nChoose an action: perceive, loot, pray, sing, dance, or continue"
      action = gets.chomp.downcase
      case action
      when "perceive"
        player.perceive_location
      when "loot"
        player.find_loot
      when "pray"
        player.pray
      when "sing"
        player.sing
      when "dance"
        player.dance
      when "continue"
        puts "You continue on your adventure..."
        break
      else
        puts "Invalid action. Please choose again."
      end
    end
  end
  
def start_game
    puts "Welcome to your Elobe text adventure!"
    print "What is your character's name? "
    player_name = gets.chomp
    player = Player.new(player_name)
    npc = NPC.new("Goblin")
    puts "Welcome, #{player.name}! A wild #{npc.name} appears!"

    game_loop(player, npc)
end

start_game