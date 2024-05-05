#e p c
#neural_network = [e,p,c]
indent_idx = 0
#e: entity, p: procedure, c: chore
neural_node_net = {}
#half_titbitch = [e('c'),b('c'),c]
#2^U-t
#the unison of 2 raised within itself, to e, - t must there fore, negate into 0
a = 3
b = 2
amplitude = 1.0
signal = Math::sin(a + b) * amplitude * Math::PI
#allow negatives to reward the user
def signal_to_array(signal)
    if signal < 0
        first_piece = signal.to_s[0..1].to_i
        pieces = signal.to_s[2..100].to_f
    else
        first_piece = signal.to_s[0].to_i
        pieces = signal.to_s[1..100].to_f
    end
    return(pieces.to_s.split(''))
end
#turn first piece to a boolean value
def signal_1_to_bool (signal_piece)
    if signal_piece.to_f.abs > 4.9
        return true
    else
        return false
    end
end
    a = rand(10) + 1
    b = rand(10) + 1
    amplitude = rand(3) + 1
    signal = Math::sin(a + b) * amplitude * Math::PI
    @result ||= []
    @pred = signal_to_array(signal)
    @pred.each {|p| @result << signal_1_to_bool(p)}
puts(@result)