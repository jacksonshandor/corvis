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
    load_memory_from_file
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
    update_word_pair_memory(input, categorize_input(input))
  
    save_user_data
    save_memory_to_file
  end

  def update_memory(user_input)
    move_to_long_term_memory(user_input)
    update_long_term_memory(user_input)
    check_and_adjust_short_term_memory if long_term_memory_updated?
    update_word_pair_memory(user_input , categorize_input(user_input))
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
    @short_term_memory.pop if @short_term_memory.count > 3
  end

  def update_word_pair_memory(input, category)
    words = input.downcase.split
    words.each_with_index do |word, index|
      next_word = words[index + 1]
      next if next_word.nil? # Skip if there's no next word

      # Use category as the key in the word pair memory
      @word_pair_memory[category] ||= {}
      @word_pair_memory[category][word] ||= Hash.new(0)
      @word_pair_memory[category][word][next_word] += 1 if  @word_pair_memory[category][word][next_word] != nil
    end

    save_memory_to_file
  end

  def save_user_data
    FileUtils.mkdir_p('data')
    File.open('data/user-pref.yaml', 'w') { |file| file.write(@user_data.to_yaml) }
  end

  def save_memory_to_file
    # Define the file path for memory data
    memory_file_path = 'data/memory/memory.yaml'

    # Load existing memory data from file if it exists
    existing_memory_data = File.exist?(memory_file_path) ? YAML.load_file(memory_file_path) : {}

    # Update emotional state in the memory data
    existing_memory_data['emotional_state'] = @emotional_state

    # Merge existing memory data with current memory data
    merged_memory_data = existing_memory_data.merge(short_term_memory: @short_term_memory, long_term_memory: @long_term_memory, word_pair_memory: @word_pair_memory)

    # Write the merged memory data to the file
    File.open(memory_file_path, 'w') { |file| file.write(merged_memory_data.to_yaml) }
  end

  def load_memory_from_file
    # Define the file path for memory data
    memory_file_path = 'data/memory/memory.yaml'

    # Load memory data from file if it exists
    if File.exist?(memory_file_path)
      memory_data = YAML.load_file(memory_file_path)

      # Load emotional state from memory data
      @emotional_state = memory_data['emotional_state'] || { happiness: 0, sadness: 0, anger: 0 }

      # Load short term memory, long term memory, and word pair memory from memory data
      @short_term_memory = memory_data['short_term_memory'] || []
      @long_term_memory = memory_data['long_term_memory'] || []
      @word_pair_memory = memory_data['word_pair_memory'] || {}
    else
      # Initialize memory data and emotional state if the file doesn't exist
      @emotional_state = { happiness: 0, sadness: 0, anger: 0 }
      @short_term_memory = []
      @long_term_memory = []
      @word_pair_memory = {}
    end
  end


  def get_user_input(input)
    update_markov_chain(input)
    update_user_preferences(input)
    @interaction_count += 1
  end

  def generate_response
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
