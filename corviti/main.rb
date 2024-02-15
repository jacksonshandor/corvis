require 'yaml'
require 'fileutils'
require 'wikipedia'

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
    @good_words = ["well", "kind", "good", "great", "better"]
    @bad_words = ["bad", "lonely","miserable","terrible","aweful"]
    @interaction_count = 0
    @emotional_state ||= @user_data['User_Intel']&.fetch('emotional_state', { happiness: 0, sadness: 0, anger: 0 })
    @word_frequency = Hash.new(0)
    @ai_keywords = ["you", "yourself", "yours", "bot", "chatbot"]
    load_memory_from_file
    clear_screen
    #populate_paired_memory_words_from_text_files('data/files_read_only/life')
  end

  def start_game
    lines_printed ||= 0
    puts "Welcome to the Corvit! Type 'quit' to exit."
    loop do
      lines_printed += 1
      print "> "
      input = gets.chomp
      clear_screen if lines_printed == 15
      break if input.downcase == 'quit'
      @session_logger.log_interaction(input, nil)
      get_user_input(input)
      if user_speaks_in_third_person?(input)
        store_third_person_subject(input)
        process_third_person_subject(input)
      end
      update_memory(input)
      generate_response(input)
      update_emotional_state(input)
      update_word_frequency(input)
      get_user_name(input)
    end
    puts "Goodbye! Thanks for chatting with Corvit."
  end

  private

  def store_third_person_subject(user_input)
    # Extract the subject from the user input
    subject = extract_subject_from_third_person_input(user_input)
    return unless subject
  
    # Store the subject in a separate category in memory
    category = :third_person_subjects
    @word_pair_memory[category] ||= {}
    @word_pair_memory[category][subject] ||= []
  
    # Split user input into words
    words = user_input.downcase.split
  
    # Store each pair of words along with the subject
    words.each_with_index do |word, index|
      next_word = words[index + 1]
      break if next_word.nil? # Skip if there's no next word
  
      # Store the pair along with the subject
      @word_pair_memory[category][subject] << { word: word, next_word: next_word }
    end
  end

  def process_third_person_subject(input)
    # Split the input into words
    words = input.downcase.split
  
    # Define a list of common noun words
    common_nouns = ["he", "she", "they", "it", "him", "her", "them", "his", "hers", "their", "its", "himself", "herself", "themselves"]
  
    # Find the first word that is a common noun
    subject = words.find { |word| common_nouns.include?(word) }
  
    # If a subject is found, store it as the key to the 'third_person_subject' key
    @user_data['User_Intel']['third_person_subject'] = subject if subject
  end

  def extract_subject_from_third_person_input(input)
    # Split the input into words
    words = input.split
  
    # Iterate over the words to find the subject
    words.each_with_index do |word, index|
      # Check if the word is capitalized and not a common noun
      if capitalized_word?(word) && !common_noun?(word)
        # If the previous word is a predicate (verb), consider it as part of the subject
        return "#{words[index - 1]} #{word}" if predicate?(words[index - 1])
        # Otherwise, return the capitalized word as the subject
        return word
      end
    end
  
    # Return nil if no subject is found
    nil
  end

  def capitalized_word?(word)
    # Check if the first character of the word is uppercase
    word =~ /^[A-Z]/
  end

  def common_noun?(word)
    # Define a list of vague pronouns
    vague_pronouns = ["he", "she", "it", "they", "them", "him", "her", "his", "hers", "its", "their", "theirs", "this", "that"]
  
    # Check if the word is included in the list of vague pronouns
    vague_pronouns.include?(word.downcase)
  end

  def predicate?(word)
    # Define a list of common predicate words
    common_predicates = ["be", "have", "do", "say", "get", "make", "go", "know", "take", "see", "come", "think", "look", "want", "give"]
  
    # Check if the word is included in the list of common predicate words
    common_predicates.include?(word.downcase)
  end

  def get_user_name(input)
    # Regular expression to match "I am [name]"
    match_data = input.match(/My name is (\w+)/i)
    if match_data
      new_name = match_data[1] # Extract the name from the match
      change_user_name(new_name) # Call the method to change the user's name
      return true # Return true to indicate that the name was successfully updated
    else
      return false # Return false if no name is found in the input
    end
  end

  def change_user_name(new_name)
    @user_name = new_name
    puts "User name changed to: #{new_name}"
  end

  def update_user_preferences(input)
    @user_data['first_person_phrases'] ||= []  # Initialize first_person_phrases array if not present
    @user_data['third_person_phrases'] ||= []  # Initialize third_person_phrases array if not present
    @user_data['first_person_goals'] ||= []    # Initialize first_person_goals array if not present
    @user_data['third_person_goals'] ||= []    # Initialize third_person_goals array if not present
  
    if user_speaks_in_first_person?(input)
      @user_data['first_person_phrases'] << input
      extract_goals_from_input(input, 'first_person_goals')
      @emotional_state[:happiness] += 1
    elsif user_speaks_in_third_person?(input)
      @user_data['third_person_phrases'] << input
      extract_goals_from_input(input, 'third_person_goals')
      @emotional_state[:sadness] -= 1
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

  def populate_paired_memory_words_from_text_files(directory_path)
    return unless !Dir.exist?(directory_path)

    Dir.glob(File.join(directory_path, '*.txt')).each do |file_path|
      current_category = File.basename(file_path, '.*')

      File.foreach(file_path) do |line|
        line.strip!
        next if line.empty?

        word, next_word = line.split(" -> ")
        @paired_memory_words[current_category][word.strip] ||= []
        @paired_memory_words[current_category][word.strip] << next_word.strip
      end
    end
  end

  def save_paired_memory_words_to_yaml(file_path)
    File.open(file_path, 'w') { |file| file.write(@paired_memory_words.to_yaml) }
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
      @emotional_state ||= { happiness: 0, sadness: 0, anger: 0 }
      @short_term_memory = []
      @long_term_memory = []
      @word_pair_memory = {}
    end
    #puts(@short_term_memory)
  end

  def update_emotional_state(input)
    words = input.downcase.split
    @good_words = ["well", "kind", "good", "great", "better"]
    @bad_words = ["bad", "lonely","miserable","terrible","aweful"]
    if words.include?(@user_name.downcase) 
      # If the user mentions the user's name, lower sadness
      @emotional_state[:sadness] -= 1
    elsif words.include?(@ai_keywords) || words.include?('corvit') || words.include?(@good_words) # Add other names the user might refer to the AI as
      # If the user mentions the AI, raise happiness
      @emotional_state[:happiness] += 1
      @emotional_state[:sadness] -= 0.5
    elsif words.include?(@bad_words)
      @emotional_state[:sadness] += 4
      @emotional_state[:happiness] -= 1
    end
    #puts(@emotional_state)
    save_user_data
  end
  
  def short_term_memory_contains_subject?(input)
    # Check if any word in the input matches the short-term memory
    @short_term_memory.any? { |topic| input.downcase.include?(topic.downcase) }
  end


  def get_user_input(input)
    update_markov_chain(input)
    update_user_preferences(input)
    update_emotional_state(input)
    if input.downcase.start_with?("read the article on:", "read the article:")
      article_title = input.sub("read the article on:", "").strip
      read_wikipedia_article(article_title)
    else
    @interaction_count += 1
    end
  end


  def read_wikipedia_article(article_title_input)
    # Extract the article title from the input
    article_title_prefix = 'read the article:'
    article_title = article_title_input.downcase.sub(article_title_prefix, '').strip
  
    # Check if the article title is empty
    if article_title.empty?
      puts "Please specify the title of the article you want to read."
      return
    end
  
    # Attempt to find the article
    article = Wikipedia.find(article_title)
  
    # Check if the article exists
    if article
      # Store the article title in short-term memory
      update_short_term_memory(article.title)
  
      # Store the content in paired word memor
  
      puts "Title: #{article.title}"
  
      # Generate a summary of the article content
      summary = generate_summary(article.content)
  
      update_paired_word_memory(summary)

      # Log the interaction with the summary
      @session_logger.log_interaction(nil, "Summary: #{summary}")
  
      # Print the summary
      puts "Summary: #{summary}"
    else
      puts "Sorry, the specified article '#{article_title}' could not be found."
    end
  end

  def standardize_article_text(article_content)
    # Remove punctuation and special characters
    cleaned_text = article_content.gsub(/[[:punct:]]/, '')
  
    # Convert the text to lowercase
    lowercase_text = cleaned_text.downcase
  
    # Split the text into words
    words = lowercase_text.split
  
    # Join the words into a single string separated by spaces
    standardized_text = words.join(' ')
  
    # Return the standardized text
    standardized_text
  end

  def generate_summary(content)
    # Split the content into sentences
    sentences = content.split(/\.\s+/)
  
    # Choose a subset of sentences for the summary
    summary_length = [3, sentences.length].min
    summary_sentences = sentences.sample(summary_length)
  
    # Join the selected sentences to form the summary
    summary_sentences.join(". ") + "."
  end
  
  def update_paired_word_memory(content)
    # Split the content into words and update paired word memory
    words = content.downcase.split
    words.each_with_index do |word, index|
      next_word = words[index + 1]
      next if next_word.nil? # Skip if there's no next word
  
      # Update word pair memory based on category
      category = :wikipedia_article
      @word_pair_memory[category] ||= {}
      @word_pair_memory[category][word] ||= {}
      @word_pair_memory[category][word][next_word] ||= 0
      @word_pair_memory[category][word][next_word] += 1
    end
  end
  
  
  def generate_response(input)
    emotional_output = generate_emotional_output
  
    # Generate response based on word pair memory
    word_pair_response = generate_word_pair_response(input)
  
    # If word pair response is available, use it, otherwise, provide a generic response
    response = word_pair_response || generate_generic_response
  
    @session_logger.log_interaction(nil, response)
    
    # Add emotional output to the response
    response += "\n" + emotional_output if emotional_output
    puts "CORVIT: " + response
  end

  def generate_emotional_output
    # Generate an output based on the current emotional state
    case dominant_emotion
    when :happiness
      "I'm glad to hear that! #{@emotional_state[:happiness]}"
    when :sadness
      "I'm sorry to hear that. #{@emotional_state[:sadness]}"
    when :anger
      "I understand your frustration. #{@emotional_state[:anger]}"
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
    if @long_term_memory.any?
      # Determine the impact of the user based on long-term memory data
      user_impact = determine_user_impact
  
      # Construct the response mentioning the user impact
      response = "I remember you said: #{@long_term_memory[-1]}"
      response += " Your feedback has been noted." if user_impact.positive? # Adjust the condition based on your criteria
      return response
    end
    nil
  end

  def determine_user_impact
    # Analyze the user's impact based on long-term memory data
    # You can calculate a score or determine the impact using various criteria such as emotional sentiment, frequency of interaction, etc.
    # For example, you can analyze the emotional sentiment of user interactions stored in long-term memory
    # and calculate an overall impact score based on the sentiment.
    # This method can be tailored to your specific requirements and data available in the long-term memory.
    # Here, I'm using a simple example to illustrate the concept.
  
    # Calculate the overall impact score based on the user's emotional sentiment
    overall_impact_score = @long_term_memory.count { |interaction| interaction.include?("positive") } -
                            @long_term_memory.count { |interaction| interaction.include?("negative") }
  
    # Adjust the impact score based on other criteria as needed
  
    # Return the overall impact score
    overall_impact_score
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
  
    # Adjust the response based on the emotional impact of the user's input
    response << adjust_response_based_on_emotion(topic)
  
    response.join(' ')
  end
  
  def adjust_response_based_on_emotion(topic)
    # Analyze the emotional impact of the user's input topic
    # You can determine the emotional impact based on various criteria such as sentiment analysis, keyword matching, etc.
    # Here, I'm providing a placeholder implementation to illustrate the concept.
    # You should replace this with your actual logic for determining the emotional impact.
  
    # Example: If the topic contains positive keywords, enhance the response with positive sentiment.
    positive_keywords = ["happy", "joy", "excited", "positive"]
    negative_keywords = ["sad", "angry", "frustrated", "negative"]
  
    if positive_keywords.any? { |keyword| topic.downcase.include?(keyword) }
      @emotional_state[:happiness] += 1
      @emotional_state[:sadness] -= 1
      return "I'm glad to hear that you're feeling positive!"
    elsif negative_keywords.any? { |keyword| topic.downcase.include?(keyword) }
      return "I'm sorry to hear that you're feeling down. Is there anything I can do to help?"
      @emotional_state[:happiness] -= 1
      @emotional_state[:sadness] += 1
    else
      return nil # No specific emotional adjustment
    end
  end

  def generate_word_pair_response(input)
    return unless @word_pair_memory.any?
  
    # Choose a random category from word_pair_memory
    category = @word_pair_memory.keys.sample
  
    # Get the weighted word pairs for the selected category
    weighted_word_pairs = calculate_weighted_word_pairs(category)
  
    # If no word pairs found for the category, return nil
    return nil if weighted_word_pairs.nil? || weighted_word_pairs.empty?
  
    # Consider long-term memory in the word pair generation
    long_term_influence = @long_term_memory.join(' ').downcase.split
    long_term_influence.each_cons(2) do |word1, word2|
      next if @word_pair_memory[category][word1].nil? || @word_pair_memory[category][word2].nil?
  
      weighted_word_pairs[word1] ||= {}
      weighted_word_pairs[word1][word2] ||= 0
      weighted_word_pairs[word1][word2] += 1
    end
  
    response = []
    current_word = weighted_word_pairs.keys.sample
    while current_word
      response << current_word
      break if punctuation?(current_word)
  
      next_word_weights = weighted_word_pairs[current_word]
      break if next_word_weights.nil? || next_word_weights.empty?
  
      current_word = weighted_sample(next_word_weights)
    end
    response << adjust_response_based_on_emotion(input)
    response.join(' ')
  end

  def punctuation?(word)
    word.end_with?('.', '!', '?')
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
    total_weight = weights.values.compact.sum
    target_weight = rand * total_weight
    cumulative_weight = 0
  
    weights.each do |word, weight|
      next if weight.nil?
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
    response = "I recall you mentioning '#{matched_phrase}'."
    
    # Adjust the response based on the emotional impact of the matched phrase
    emotional_adjustment = adjust_response_based_on_emotion(matched_phrase)
    response += " #{emotional_adjustment}" if emotional_adjustment
  
    response += " What else would you like to discuss?"
    response
  end
  

  def generate_generic_response
    "I'm not sure what you mean. Can you elaborate?"
  end
end

# Example usage:
chatbot = ChatBot.new("John")
chatbot.start_game
