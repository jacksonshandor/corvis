class Character
    attr_accessor :name, :health, :strength, :intelligence
  
    def initialize(name, health, strength, intelligence)
      @name = name
      @health = health
      @strength = strength
      @intelligence = intelligence
    end
  
    def roll_d(numbersides,countdie)
        total = 0
        numbersides.times do
            total += rand(countdie) + 1
        end
        return total
    end

    def flair_text(action, roll)
        # Define flair text for different actions
        flair_texts = {
          perceive: [
            "You stumble around, clueless.",
            "You notice the obvious.",
            "You catch some details.",
            "You perceive the hidden secrets of your surroundings.",
            "You see everything, even the very fabric of reality."
          ],
          loot: [
            "You find nothing but dust.",
            "You find something barely worth your while.",
            "You discover something useful.",
            "You unearth a valuable item!",
            "You hit the jackpot, finding a rare treasure!"
          ],
          # Define similar arrays for pray, sing, dance
        pray: [
            "You mutter words, but they feel empty.",
            "Your prayers whisper into the void, unanswered.",
            "You feel a faint warmth as your prayers are acknowledged.",
            "A sense of peace fills you, your faith is strong.",
            "Divine energy envelops you, a deity has heard your plea."
          ],
          
          sing: [
            "Your voice cracks, the notes fall flat.",
            "You carry a tune, but it's hardly enchanting.",
            "Your song is pleasant, drawing a few smiles.",
            "Your voice captivates all who hear, leaving them in awe.",
            "Angels weep at the beauty of your voice, a true masterpiece."
          ],
          
          dance: [
            "You trip over your own feet.",
            "It's a simple step-to-step, but you manage not to fall.",
            "Your moves draw some attention, not bad at all.",
            "You move with grace, the crowd is impressed.",
            "A stunning performance, they'll talk about it for days!"
          ]
        }
    
        # Determine index based on roll
        index = case roll
                when 1 then 0 # Natural 1, critical failure
                when 2..10 then 1 # Low success
                when 11..15 then 2 # Moderate success
                when 16..19 then 3 # High success
                when 20 then 4 # Natural 20, critical success
                else 1 # Default to low success if out of bounds
                end
    
        flair_texts[action][index]
      end

    def attack(target)
      damage = self.strength + roll_d(4,self.intelligence)
      target.health -= damage
      puts "#{self.name} attacks #{target.name} for #{damage} damage."
    end
  
    def speak
      # Placeholder for speaking functionality
      puts "#{name} says something profound."
    end
  end

  class Player < Character
    attr_accessor :feats, :faith
  
    def initialize(name)
      super(name, 100, 10, 10) # Default stats
      @feats = []
      @faith = 5 # Initialize faith stat
    end
  
    # Other methods...

    def gain_feat(new_feat)
        @feats << new_feat
        puts "#{name} has gained a new feat: #{new_feat}!"
      end
    
      def increase_stat
        stat_choice = rand(2) # Randomly choose between 0 and 1
        if stat_choice == 0
          self.strength += 1
          puts "#{name}'s strength has increased by 1!"
        else
          self.intelligence += 1
          puts "#{name}'s intelligence has increased by 1!"
        end
      end
  
    def perceive_location
        roll = rand(1..20) + self.intelligence
        puts "#{name} rolls for Perception: #{roll}"
        action_flair = flair_text(:perceive, roll)
        puts action_flair
      end
  
    def find_loot
      roll = roll_d(1,20) + self.strength
      puts "#{name} rolls for Luck: #{roll}"
      action_flair = flair_text(:loot, roll)
      puts action_flair
      # Determine loot based on roll
    end
  
    def pray
        roll = rand(1..20) + self.faith
        puts "#{name} rolls for Prayer: #{roll}"
        action_flair = flair_text(:pray, roll)
        puts action_flair
      end
    
      def sing
        roll = rand(1..20) + self.intelligence
        puts "#{name} rolls for Singing: #{roll}"
        action_flair = flair_text(:sing, roll)
        puts action_flair
      end
    
      def dance
        roll = rand(1..20) + self.strength
        puts "#{name} rolls for Dancing: #{roll}"
        action_flair = flair_text(:dance, roll)
        puts action_flair
      end
  end

class NPC < Character
    def initialize(name)
        super(name,100,2,4)
    end
end


def combat(player, npc)
    while player.health > 0 && npc.health > 0
        damage = player.attack(npc)
        damage_npc = npc.attack(player) if npc.health > 0
    end

    if player.health <= 0
        puts "#{player.name} has been defeated."
    else
        puts "#{npc.name} has been defeated."
    end
end