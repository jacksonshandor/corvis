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
    @emotional_state = @user_data['User_Intel']&.fetch('emotional_state', { happiness: 0, sadness: 0, anger: 0 })
    @word_frequency = Hash.new(0)
    @ai_keywords = ["you", "yourself", "yours", "bot", "chatbot"]
    load_memory_from_file
  end

  def start_game
    lines_printed = 0
    puts "Welcome to the Corvit! Type 'quit' to exit."
    loop do
      print "> "
      input = gets.chomp
      break if input.downcase == 'quit'
      @session_logger.log_interaction(input, nil)
      get_user_input(input)
      if user_speaks_in_first_person?(input)
        # User is speaking in the first person
      else
        # User is not speaking in the first person
      end
      update_memory(input)
      generate_response
      update_word_frequency(input)
      lines_printed += 1
      clear_screen if lines_printed == 15
    end
    puts "Goodbye! Thanks for chatting with Corvit."
  end

  private

  def update_user_preferences(input)
    @user_data['first_person_phrases'] ||= []  # Initialize first_person_phrases array if not present
    @user_data['third_person_phrases'] ||= []  # Initialize third_person_phrases array if not present
    @user_data['first_person_goals'] ||= []    # Initialize first_person_goals array if not present
    @user_data['third_person_goals'] ||= []    # Initialize third_person_goals array if not present
  
    if user_speaks_in_first_person?(input)
      @user_data['first_person_phrases'] << input
      extract_goals_from_input(input, 'first_person_goals')
    elsif user_speaks_in_third_person?(input)
      @user_data['third_person_phrases'] << input
      extract_goals_from_input(input, 'third_person_goals')
    end
  
    save_user_data
  end

  def extract_goals_from_input(input, goal_type)
    goals = []
    # Extract goals from input (you can implement this based on your specific criteria)
    # For example, you can look for keywords or patterns indicating goals in the input
    # and add them to the goals array
    # Example:
    # if input includes 'goal: ', add the text after 'goal: ' to the goals array
    goals = input.scan(/goal: (.+)/i).flatten if input.downcase.include?('goal: ')
    
    # Append extracted goals to the user data
    @user_data[goal_type] += goals
  end

  def user_speaks_in_third_person?(input)
    third_person_indicators = %w[he she they his her their you your]
    words = input.downcase.split
    words.any? { |word| third_person_indicators.include?(word) }
  end

  def load_user_data
    if File.exist?('data/user-pref.yaml')
      @user_data = YAML.load_file('data/user-pref.yaml')
      @user_data ||= {}
      @user_data['User_Intel'] ||= {}
      @user_data
    else
      { 'User_Intel' => {} } # Return default user data if the file doesn't exist
    end
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
    load_phrases_from_user_data(user_input)
    move_to_long_term_memory(user_input)
    #update_long_term_memory(user_input)
    check_and_adjust_short_term_memory if long_term_memory_updated?
    update_word_pair_memory(user_input)
    move_to_long_term_memory(@short_term_memory.first) if @short_term_memory.size > 1 # Move new data to long term memory if it's the only item in short term memory
  #save_user_data
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
      @user_data['User_Intel'] ||= {}
      @user_data['User_Intel']['emotional_state'] = @emotional_state
      File.open('data/user-pref.yaml', 'w') { |file| file.write(@user_data.to_yaml) }
    end

  def save_memory_to_file
    # Define the file paths for memory data
    FileUtils.mkdir_p('data/memory')

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
    emotional_output = generate_emotional_output
    if @user_data.empty?
      response = ["Hello!", "How can I assist you today?", "What would you like to talk about?"].sample
    else
      long_term_response = generate_long_term_response
      word_pair_response = generate_word_pair_response
      short_term_match_response = generate_short_term_match_response
      response = short_term_match_response ? construct_long_term_memory_response(short_term_match_response) :
                 word_pair_response || long_term_response || generate_generic_response
    end
    @session_logger.log_interaction(nil, response)
    
    # Add emotional output to the response
    response += "\n" + emotional_output if emotional_output
    puts "CORVIT: " + response
  end

  def generate_emotional_output
    # Generate an output based on the current emotional state
    case dominant_emotion
    when :happiness
      "I'm glad to hear that!"
    when :sadness
      "I'm sorry to hear that."
    when :anger
      "I understand your frustration."
    else
      nil # No specific emotional output
    end
  end

  def dominant_emotion
    # Determine the dominant emotion based on the emotional state
    @emotional_state.max_by { |emotion, value| value }.first
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
    return unless @word_pair_memory.any?
  
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

  def load_phrases_from_user_data(user_input)
    # Load first person phrases and third person phrases from user data
    first_person_phrases = @user_data.dig('User_Intel', 'first_person_phrases') || []
    third_person_phrases = @user_data.dig('User_Intel', 'third_person_phrases') || []
  
    # Check if user input contains any first person or third person phrases
    phrases_to_load = (first_person_phrases + third_person_phrases).select { |phrase| user_input.downcase.include?(phrase.downcase) }
  
    # Load the identified phrases into short-term memory
    @short_term_memory.concat(phrases_to_load)
  end

  def weighted_phrase_length(weighted_word_pairs)
    total_weight = weighted_word_pairs.values.map(&:values).flatten.sum
    phrase_length_probabilities = { 3 => 0.1, 5 => 0.3, 7 => 0.4, 10 => 0.2 }
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
