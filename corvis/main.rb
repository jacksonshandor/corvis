require 'yaml'
require 'fileutils'

class SessionLogger
  def initialize(log_file)
    @log_file = log_file
  end

  def log_interaction(user_input, bot_response)
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = { timestamp: timestamp, user_input: user_input, bot_response: bot_response }
    File.open(@log_file, 'a') { |file| file.puts(log_entry.to_yaml) }
  end
end

class RatBot
  attr_reader :name, :level, :exp_gain, :exp_to_next_level, :stats, :training

  def initialize(name, level, exp_gain, difficulty = 1)
    name_list = ["Rat", "Mouse", "Rodent", "Vermin", "Pest", "Critter"]
    @name = name_list.sample + " Bot"
    @stats = { hp: rand(10 * difficulty) + 1, attack: rand(5 * difficulty) + 1, defense: rand(5 * difficulty) + 1 }
    @level = level
    @exp_gain = exp_gain
    @training = []
    (@level + 1).times do
      @training << ["Attack", "Defend"].sample
    end
  end

  def gain_exp(exp)
    return @exp_gain
  end

  def attack(player_stats)
    damage = @stats[:attack] - player_stats[:defense]
    player_stats[:hp] -= damage if damage > 0
    return "#{@name} attacks! Dealt #{damage} damage! \n"
  end

  def defend(player_stats)
    damage = player_stats[:attack] - @stats[:defense]
    @stats[:hp] -= damage if damage > 0
    return "#{@name} defends! Took #{damage} damage! \n"
  end
end

#make it so the chat bot has a level, exp, and a way to level up.
#make it so interacting with the chat bot, has a chance to get into combat with rat bots.
#make it so the perks of the chat bot are geared towards combat.
#make it so the chat bot can be trained in what order of choice to make in a combat situation, based on level, perks and stats.
#pick a set difficulty rating for the game, in the prestate of the start_game loop

class ChatBot
  attr_reader :interaction_count
  attr_accessor :emotional_state

  def initialize(user_name)
    @user_name = user_name
    @user_data = load_user_data
    @short_term_memory = []
    @long_term_memory = []
    @word_pair_memory = {}
    @short_term_memory_file = 'data/memory/short_term_memory.txt'
    @long_term_memory_file = 'data/memory/long_term_memory.txt'
    @word_pair_memory_file = 'data/memory/word_pair_memory.yaml'
    @session_logger = SessionLogger.new('session.log')
    @interaction_count = 0
    @emotional_state = { happiness: 0, sadness: 0, anger: 0 }
    @word_frequency = Hash.new(0)
    @ai_keywords = ["you", "yourself", "yours", "bot", "chatbot"]
    @stats = { level: 1, exp: 0, exp_to_next_level: 100, hp: 100, attack: 10, defense: 5 }
    @perks = { "Attack" => [1, "A standard attack"], "Defense" => [1, "A standard defense"], "Heal" => [1, "Heal 10 HP"] }
    @training = []
    @ratbots = []
    @spawn_rate = 0.1
    @spawn_rate_increase = 0.1
    @spawn_rate_cap = 0.5
    @spawn_difficulty = 1
    load_memory_from_file

  end

  def start_game
    lines_printed = 0
    puts "Welcome to the Corvit! Type 'quit' to exit."
    puts "Type 'stats' to view your stats."
    puts "Please select a difficulty setting: 1[default], 2, 3"
    @spawn_difficulty = gets.chomp.downcase.to_i
    if @spawn_difficulty == ''
      @spawn_difficulty = 1
    end
    loop do
      print "> "
      input = gets.chomp
      load_stats if File.exist?('stats.yaml')
      load_training if File.exist?('training.yaml')
      break if input.downcase == 'quit' || @stats[:hp] <= 0
      if input.downcase == 'stats'
        puts "Level: #{@stats[:level]}"
        puts "Exp: #{@stats[:exp]}/#{@stats[:exp_to_next_level]}"
        puts "HP: #{@stats[:hp]}"
        puts "Attack: #{@stats[:attack]}"
        puts "Defense: #{@stats[:defense]}"
      end
      if input.downcase == 'train'
        train_corvis
      end
      if input.downcase == 'trained'
        puts @training
      end
      @session_logger.log_interaction(input, nil)
      get_user_input(input)
      if user_speaks_in_first_person?(input)
        # User is speaking in the first person
      else
        # User is not speaking in the first person
      end
      lines_printed += 1
      if lines_printed == 15
        clear_screen 
        lines_printed = 0
        @stats[:exp] += 1
        puts "Corvis gains 1 exp!"
      end
      update_memory(input)
      generate_response
      update_word_frequency(input)
      #spawn_ratbots if rand(10) * @spawn_rate < 0.5
      #spawn ratbots if random is less than spawn rate
      spawn_ratbots if rand(10 + @spawn_rate * 10) < @spawn_rate * 10
    end
    puts "Goodbye! Thanks for chatting with Corvit."
  end

  private

  def train_corvis
    puts "Corvis can be trained in advance up to #{@stats[:level]+1} moves based on its level."
    (@stats[:level] + 1).times do
      puts "Choose a perk to use: "
      puts @perks.keys
      input = gets.chomp
      if @perks.keys.include?(input)
        @training << { input => @perks[input] }
      end
    end
    save_training(@training)
  end

  def save_training(training)
    File.open('training.yaml', 'w') { |file| file.write(training.to_yaml) }
  end

  def load_training
    @training = YAML.load_file('training.yaml')
  end


  def load_stats
    @stats = YAML.load_file('stats.yaml')
  end

  def save_stats(stats)
    File.open('stats.yaml', 'w') { |file| file.write(stats.to_yaml) }
  end

  def spawn_ratbots
    ratbot = RatBot.new("Rat", 1, 10,rand(@spawn_difficulty) + 1)
    @ratbots << ratbot
    puts "A wild #{ratbot.name} has appeared!"
    @ratbots.size.times do |i|
      go_to_combat(@ratbots.last)
    end
  end

  #create a combat log in seession.log
  def combat_log(player, ratbot)
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = { timestamp: timestamp, player: player, ratbot: ratbot }
    File.open('session.log', 'a') { |file| file.puts(log_entry.to_yaml) }
  end

  def go_to_combat(ratbot)
    response = "A #{ratbot.name} has appeared! \n"
    combat_round = 0
    loop do
      response += "Corvis: #{@stats[:hp]} HP \n"
      if @training.size == 0
        decision = @perks.keys.sample
      else
        choices = @training[combat_round].keys
        decision = choices[combat_round % @training.size]
      end
      response += "Corvis will #{decision}... \n"
      if decision == "Attack"
        response += attack(ratbot) + "\n"
      elsif decision == "Defend"
        response += defend(ratbot) + "\n"
      elsif decision == "Heal"
        @stats[:hp] += 10
        response += "Corvis heals 10 HP! \n"
      end
      response += "#{ratbot.name}: #{ratbot.stats[:hp]} HP \n"
      decision_ratbot = ratbot.training[combat_round % ratbot.training.size]
      if decision_ratbot == "attack"
        response += ratbot.attack(@stats)
      else
        response += ratbot.defend(@stats)
      end
      combat_round += 1
      puts response
      if ratbot.stats[:hp] <= 0
        puts "#{ratbot.name} has been defeated!"
        puts exp_gain(ratbot.exp_gain)
        if @stats[:exp] >= @stats[:exp_to_next_level]
          level_up
        end
        save_stats(@stats)
        break
      end
      combat_log(@stats, response)
      sleep(1)
      response = ""
    end
  end

  def attack(ratbot)
    damage = @stats[:attack] - ratbot.stats[:defense]
    ratbot.stats[:hp] -= damage if damage > 0
    return "Corvis attacks! Dealt #{damage} damage!"
  end

  def defend(ratbot)
    damage = ratbot.stats[:attack] - @stats[:defense]
    @stats[:hp] -= damage if damage > 0
    return "Corvis defends! Took #{damage} damage!"
  end

  def exp_gain(exp)
    @stats[:exp] += exp
    return "Corvis gained #{exp} exp!"
  end

  def level_up
    @stats[:level] += 1
    @stats[:exp] = 0
    @stats[:exp_to_next_level] *= 2
    @stats[:hp] += 10
    @stats[:attack] += 5
    @stats[:defense] += 2
    puts "Corvis has leveled up to level #{@stats[:level]}!"
    @spawn_rate += @spawn_rate_increase
  end

  def update_user_preferences(input)
    @user_data['first_person_phrases'] ||= []  # Initialize first_person_phrases array if not present
    @user_data['first_person_phrases'] << input if user_speaks_in_first_person?(input)
    save_user_data
  end

  def load_user_data
    YAML.load_file('data/user-pref.yaml') if File.exist?('data/user-pref.yaml')
  end

  def directed_at_ai?(input)
    # Convert input to lowercase for case-insensitive matching
    input_downcase = input.downcase
    # Check if any of the AI keywords are present in the input
    @ai_keywords.any? { |keyword| input_downcase.include?(keyword) }
  end

  def update_word_frequency(input)
    # Split the input into words
    words = input.downcase.split

    # Update the word frequency hash
    if words.length > 0
      first_word = words[0]
      @word_frequency[first_word] += 1
    end
  end

  def update_markov_chain(input)
    update_short_term_memory(input)
    update_long_term_memory(input)
    update_word_pair_memory(input)
  
    save_user_data
    save_memory_to_file
  end

  def update_memory(user_input)
    move_to_long_term_memory(user_input)
    update_long_term_memory(user_input)
    check_and_adjust_short_term_memory if long_term_memory_updated?
    update_word_pair_memory(user_input)
    #save_user_data
    #save_memory_to_file
  end

  def move_to_long_term_memory(user_input)
    @short_term_memory.each do |topic|
      if user_input.downcase.include?(topic.downcase)
        @long_term_memory << topic
        @short_term_memory.delete(topic)
        return
      end
    end
  end

  def update_short_term_memory(input)
    @short_term_memory << input
    @short_term_memory.shift if @short_term_memory.length > 3
  end

  def update_long_term_memory(user_input)
    @long_term_memory << user_input
    @long_term_memory.shift if @long_term_memory.size > 5
  end

  def long_term_memory_updated?
    @long_term_memory.size >= 5 && @long_term_memory.last != @long_term_memory[-2]
  end

  def check_and_adjust_short_term_memory
    if @short_term_memory.size > 3
      @short_term_memory.shift(@short_term_memory.size - 3)
    end
  end

  def update_word_pair_memory(user_input)
    words = user_input.downcase.split
    words.each_with_index do |word, index|
      next_word = words[index + 1]
      next if next_word.nil? # Skip if there's no next word
  
      # Determine the category of the word
      category = categorize_input(user_input)
  
      # Update word pair memory based on category
      @word_pair_memory[category] ||= {}
      @word_pair_memory[category][word] ||= {}
      @word_pair_memory[category][word][next_word] ||= 0
      
      # Increment the count only if the phrase is used again
      @word_pair_memory[category][word][next_word] += 1 if word_pair_repeated?(category, word, next_word)
    end
  end
  
  def word_pair_repeated?(category, word, next_word)
    return false unless @word_pair_memory[category] && @word_pair_memory[category][word]
  
    # Check if the next word exists in the word pair memory for the given category and word
    @word_pair_memory[category][word].key?(next_word)
  end

  def save_user_data
    FileUtils.mkdir_p('data')
    File.open('data/user-pref.yaml', 'w') { |file| file.write(@user_data.to_yaml) }
  end

  def save_memory_to_file
    # Define the file paths for memory data
    short_term_memory_file_path = 'data/memory/short_term_memory.txt'
    long_term_memory_file_path = 'data/memory/long_term_memory.txt'
    word_pair_memory_file_path = 'data/memory/word_pair_memory.yaml'
  
    # Append short term memory to file
    File.open(short_term_memory_file_path, 'w') { |file| file.puts(@short_term_memory.join("\n")) }
  
    # Append long term memory to file
    File.open(long_term_memory_file_path, 'w') { |file| file.puts(@long_term_memory.join("\n")) }
  
    # Save word pair memory to file
    File.open(word_pair_memory_file_path, 'w') { |file| file.write(@word_pair_memory.to_yaml) }
  end

  def load_memory_from_file
    # Define the file path for memory data
    memory_file_path = 'data/memory/word_pair_memory.yaml'

    # Load memory data from file if it exists
    if File.exist?(memory_file_path)
      short_term_memory_file_path = 'data/memory/short_term_memory.txt'
      long_term_memory_file_path = 'data/memory/long_term_memory.txt'
      word_pair_memory_file_path = 'data/memory/word_pair_memory.yaml'

      # Load short term memory from file
      @short_term_memory = File.exist?(short_term_memory_file_path) ? File.readlines(short_term_memory_file_path).map(&:chomp) : []

      # Load long term memory from file
      @long_term_memory = File.exist?(long_term_memory_file_path) ? File.readlines(long_term_memory_file_path).map(&:chomp) : []

      # Load word pair memory from file
      @word_pair_memory = File.exist?(word_pair_memory_file_path) ? YAML.load_file(word_pair_memory_file_path) : {}
    else
      puts("NO FILE FOUND")
      # Initialize memory data and emotional state if the file doesn't exist
      @emotional_state = { happiness: 0, sadness: 0, anger: 0 }
      @short_term_memory = []
      @long_term_memory = []
      @word_pair_memory = {}
    end
    puts(@short_term_memory)
  end

  def update_emotional_state(input)
    words = input.downcase.split
    if words.include?(@user_name.downcase)
      # If the user mentions the user's name, lower sadness
      @emotional_state[:sadness] -= 1
    elsif words.include?('ai') || words.include?('corvit')  # Add other names the user might refer to the AI as
      # If the user mentions the AI, raise happiness
      @emotional_state[:happiness] += 1
    elsif !short_term_memory_contains_subject?(input)
      # If the subject is not in the short-term memory, increase sadness
      @emotional_state[:sadness] += 1
    end
  end
  
  def short_term_memory_contains_subject?(input)
    # Check if any word in the input matches the short-term memory
    @short_term_memory.any? { |topic| input.downcase.include?(topic.downcase) }
  end


  def get_user_input(input)
    update_markov_chain(input)
    update_user_preferences(input)
    update_emotional_state(input)
    @interaction_count += 1
  end

  def generate_response
    if @user_data.empty?
      response = ["Hello!", "How can I assist you today?", "What would you like to talk about?"].sample
    else
      long_term_response = generate_long_term_response
      word_pair_response = generate_word_pair_response
      short_term_match_response = generate_short_term_match_response
      response = word_pair_response || long_term_response || short_term_match_response
    end
    @session_logger.log_interaction(nil, response)
    
    puts response
  end

  def clear_screen
    system('clear') || system('cls')
  end

  def generate_long_term_response
    @long_term_memory.any? ? "I remember you said: #{@long_term_memory[-1]}" : nil
  end


  def user_speaks_in_first_person?(input)
    first_person_indicators = %w[I me my myself mine]
    words = input.downcase.split
    words.any? { |word| first_person_indicators.include?(word) }
  end

  def generate_long_term_memory_response(topic)
    response = []
    current_word = topic.downcase
    phrase_length.times do
      response << current_word
      next_word_weights = @word_pair_memory[current_word]
      break if next_word_weights.nil? || next_word_weights.empty?
      current_word = weighted_sample(next_word_weights)
    end
    response.join(' ')
  end

  def generate_word_pair_response
    return unless @word_pair_memory.keys.size > 0
  
    # Choose a random category from word_pair_memory
    category = @word_pair_memory.keys.sample
  
    # Get the weighted word pairs for the selected category
    weighted_word_pairs = calculate_weighted_word_pairs(category)
  
    # If no word pairs found for the category, return nil
    return nil if weighted_word_pairs.nil? || weighted_word_pairs.empty?
  
    response = []
    phrase_length = weighted_phrase_length(weighted_word_pairs)
    current_word = weighted_word_pairs.keys.sample
    phrase_length.times do
      response << current_word
      next_word_weights = weighted_word_pairs[current_word]
      break if next_word_weights.nil? || next_word_weights.empty?
  
      current_word = weighted_sample(next_word_weights)
    end
    response.join(' ')
  end

  def weighted_phrase_length(weighted_word_pairs)
    total_weight = weighted_word_pairs.values.map(&:values).flatten.sum
    phrase_length_probabilities = { 13 => 0.1, 15 => 0.3, 27 => 0.4, 30 => 0.2 }
    weighted_lengths = phrase_length_probabilities.transform_values { |prob| prob * total_weight }
    length_sample(weighted_lengths)
  end

  def length_sample(weighted_lengths)
    total_weight = weighted_lengths.values.sum
    target_weight = rand * total_weight
    cumulative_weight = 0
    weighted_lengths.each do |length, weight|
      cumulative_weight += weight
      return length if cumulative_weight >= target_weight
    end
  end

  def weighted_sample(weights)
    total_weight = weights.values.sum
    target_weight = rand * total_weight
    cumulative_weight = 0
    weights.each do |word, weight|
      cumulative_weight += weight
      return word if cumulative_weight >= target_weight
    end
  end

  def categorize_input(input)
    case input
    when /\?$/
      :question
    when /\!$/
      :exclamation
    else
      :statement
    end
  end

  def calculate_weighted_word_pairs(category)
    return nil unless @word_pair_memory.key?(category)
  
    weighted_word_pairs = {}
    @word_pair_memory[category].each do |word_pair, weight|
      # Process word pairings specific to the given category
      weighted_word_pairs[word_pair] = weight
    end
    weighted_word_pairs
  end

  def generate_short_term_match_response
    @short_term_memory.each do |short_term|
      @long_term_memory.each { |long_term| return long_term if long_term.downcase.include?(short_term.downcase) }
    end
    nil
  end

  def construct_long_term_memory_response(matched_phrase)
    "I recall you mentioning '#{matched_phrase}'. What else would you like to discuss?"
  end

  def generate_generic_response
    "I'm not sure what you mean. Can you elaborate?"
  end
end

# Example usage:
chatbot = ChatBot.new("John")
chatbot.start_game
