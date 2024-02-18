class Location
    attr_accessor :name, :description, :connections

    def initialize(name, description)
        @name = name
        @description = description
        @connections = {}
    end
    
    def connect(location, direction)
        @connections[direction] = location
    end
end
