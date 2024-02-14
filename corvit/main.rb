require 'yaml'
require 'fileutils'

class ChatBot
  def initialize(user_name)
    @user_name = user_name
    @user_data = load_user_data
    @short_term_memory = []
    @long_term_memory = []
    @short_term_memory_file = 'data/memory/short_term_memory.txt'
    @long_term_memory_file = 'data/memory/long_term_memory.txt'
    @word_pair_memory_file = 'data/memory/word_pair_memory.yaml'
    @word_pair_memory = load_word_pair_memory

  end

  def start_game
    lines_printed = 0
    puts "Welcome to the Corvit! Type 'quit' to exit."
    loop do
      print "> "
      input = gets.chomp
      break if input.downcase == 'quit'
      get_user_input(input)
      generate_response
      lines_printed += 1
      if lines_printed == 15
        system('clear') || system('cls')  # Clear the screen
        lines_printed = 0  # Reset the counter
      end
    end
    puts "Goodbye! Thanks for chatting with Corvit."
  end

  private

  def load_user_data
    # Load user data from YAML file
    if File.exist?('data/user-pref.yaml')
      YAML.load_file('data/user-pref.yaml')
    else
      {}
    end
  end

  def load_word_pair_memory
    # Load word pair memory from file
    if File.exist?(@word_pair_memory_file)
      YAML.load_file(@word_pair_memory_file)
    else
      {}
    end
  end

  def update_markov_chain(input)
    # Update short term memory
    @short_term_memory << input
    @short_term_memory.shift if @short_term_memory.length > 3
  
    # Update long term memory
    @long_term_memory << input
    @long_term_memory.shift if @long_term_memory.length > 5
  
    # Update word pair memory
    words = input.downcase.split
    words.each_with_index do |word, index|
      next_word = words[index + 1]
      @word_pair_memory[word] ||= Hash.new(0)
      @word_pair_memory[word][next_word] += 1 if next_word
    end
  
    save_user_data
    save_memory_to_file
  end
  
  def calculate_weighted_word_pairs
    weighted_word_pairs = {}
    @word_pair_memory.each do |word, next_word_counts|
      total_next_word_count = next_word_counts.values.sum
      weighted_word_pairs[word] = Hash[next_word_counts.map { |next_word, count| [next_word, count.to_f / total_next_word_count] }]
    end
    weighted_word_pairs
  end

  def save_user_data
    # Create data folder if it doesn't exist
    FileUtils.mkdir_p('data')
    File.open('data/user-pref.yaml', 'w') { |file| file.write(@user_data.to_yaml) }
  end

  def save_memory_to_file
    # Create memory folder if it doesn't exist
    FileUtils.mkdir_p('data/memory')
    
    # Save short term memory to file
    File.open(@short_term_memory_file, 'w') { |file| file.write(@short_term_memory.join("\n")) }
    
    # Save long term memory to file
    File.open(@long_term_memory_file, 'w') { |file| file.write(@long_term_memory.join("\n")) }

    # Save word pair memory to file
    File.open(@word_pair_memory_file, 'w') { |file| file.write(@word_pair_memory.to_yaml) }
  end

  def get_user_input(input)
    update_markov_chain(input)
  end

  def generate_response
    if @user_data.empty?
      response = ["Hello!", "How can I assist you today?", "What would you like to talk about?"].sample
    else
      long_term_response = generate_long_term_response
      word_pair_response = generate_word_pair_response
      if long_term_response
        response = long_term_response
      elsif word_pair_response
        response = word_pair_response
      else
        response = generate_short_term_response
      end
    end
    response = word_pair_response
    puts response
  end

  def generate_long_term_response
    if @long_term_memory.any?
      return "I remember you said: #{@long_term_memory[-1]}"
    end
    nil
  end

  def generate_word_pair_response
    if @word_pair_memory.any?
      weighted_word_pairs = calculate_weighted_word_pairs
      response = []
      phrase_length = weighted_phrase_length(weighted_word_pairs)
      current_word = weighted_word_pairs.keys.sample
      phrase_length.times do
        response << current_word
        next_word_weights = weighted_word_pairs[current_word]
        break if next_word_weights.nil? || next_word_weights.empty?
        current_word = weighted_sample(next_word_weights)
      end
      return "Based on what I've learned, '#{response.join(' ')}' sounds interesting."
    end
    nil
  end
  
  def weighted_phrase_length(weighted_word_pairs)
    total_weight = weighted_word_pairs.values.map(&:values).flatten.sum
    phrase_length_probabilities = { 3 => 0.1, 5 => 0.3, 7 => 0.4, 10 => 0.2 }  # Adjust probabilities as needed
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
  
  # Helper method to perform weighted random sampling
  def weighted_sample(weights)
    total_weight = weights.values.sum
    target_weight = rand * total_weight
    cumulative_weight = 0
    weights.each do |word, weight|
      cumulative_weight += weight
      return word if cumulative_weight >= target_weight
    end
  end

  def calculate_weighted_word_pairs
    weighted_word_pairs = {}
    @word_pair_memory.each do |word, next_words|
      next_word_counts = next_words.group_by { |w| w }.transform_values(&:size)
      total_next_word_count = next_word_counts.values.sum
      weighted_word_pairs[word] = next_word_counts.transform_values { |count| count.to_f / total_next_word_count }
    end
    weighted_word_pairs
  end


  def generate_short_term_response
    if @short_term_memory.any?
      return "You just said: #{@short_term_memory[-1]}"
    end
    nil
  end
end

# Example usage:
chatbot = ChatBot.new("John")
chatbot.start_game
