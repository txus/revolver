require "revolver/version"
require "parser/current"
require "unparser"

VERBOSE = ENV['VERBOSE']

class Random
  ALLOWED_SYMBOL_CHARACTERS = Array('a'..'z') + Array('A'..'Z')

  MAX_DEPTH=2

  TYPES = {
    true: TrueClass,
    false: FalseClass,
    nil: NilClass,
    int: Integer,
    float: Float,
    str: String,
    array: Array,
    hash: Hash,
    sym: Symbol,
    irange: Range,
    erange: Range,
    self: Object
  }

  def self.true(depth=0)
  end

  def self.false(depth=0)
  end

  def self.nil(depth=0)
  end

  def self.int(depth=0)
    rand(100) - 100
  end

  def self.float(depth=0)
    int.to_f + rand
  end

  def self.str(depth=0)
    Array.new(rand(50)) { rand(126).chr }.join
  end

  def self.array(depth=0)
    length = rand(100)
    types = depth >= MAX_DEPTH ? NODE_TYPES - [:array, :hash] : NODE_TYPES
    length.times.map { node(types.sample, depth+1) }
  end

  def self.hash(depth=0)
    types = depth >= MAX_DEPTH ? NODE_TYPES - [:hash, :array] : NODE_TYPES
    length = rand(10)
    length.times.map { Parser::AST::Node.new(:pair, [node(types.sample, depth+1), node(types.sample, depth+1)]) }.uniq
  end

  def self.sym(depth=0)
    Array.new(rand(50).next) { ALLOWED_SYMBOL_CHARACTERS.sample}.join.to_sym
  end

  def self.irange(depth=0)
    [node(:int), node(:int)]
  end

  def self.erange(depth=0)
    [node(:int), node(:int)]
  end

  def self.self(depth=0)
  end

  def self.send(depth=0)
    types = depth >= MAX_DEPTH  ? NODE_TYPES - [:send] : NODE_TYPES
    receiver = [node(:self), node(types.sample, depth+1)].sample
    klass = TYPES[receiver.type]
    meth = klass.methods.sample
    arity = klass.method(meth).arity
    arguments = arity.times.map { node(types.sample, depth+1) }
    [receiver, meth, arguments].flatten
  end

  def self.node(type=nil,depth=0)
    type ||= NODE_TYPES.sample
    children = Array(__send__(type, depth))
    Parser::AST::Node.new(type, children)
  end

  NODE_TYPES = Parser::Meta::NODE_TYPES.select { |t| methods(false).include? t }
end

class Program
  def self.random
    new(Random.node)
  end

  def initialize(ast)
    @ast = ast
  end

  def source
    @source ||= Unparser.unparse(@ast)
  end

  def valid?
    run
    true
  rescue SyntaxError, Exception
    false
  end

  def mutate
    r = @ast.children.sample
    index = @ast.children.index(r)
    Program.new(@ast.class.new(@ast.type, @ast.children.each_with_index.map { |x, idx|
      if idx == index
        Random.node
      else
        x
      end
    }))
  end

  def fitness(tests)
    return 0 unless valid?
    retval = run
    puts source if VERBOSE
    total, passed = tests.count, tests.select { |t|
      t.call(retval) rescue false
    }.count
    passed / total.to_f
  end

  def run
    eval source
  end
end

class Generation
  def self.random(tests)
    initial_programs = rand(200).times.map { Program.random }
    new(initial_programs, tests)
  end

  def initialize(parents, tests)
    @programs = parents.map(&:mutate)
    @tests = tests
  end

  def evolve_until_winner
    puts "Family tree starts. Generation starts with #{count} population, from which #{survivors.count} survived and may breed."
    if winner
      winner
    else
      n = self
      while n.alive? && !n.winner
        n = next_generation
        puts "Next generation has #{n.count} population, from which #{n.survivors.count} survived and may breed."
      end
      n.winner
    end
  end

  def winner
    found, _ = programs_with_fitness.detect { |(p,f)| f == 1.0 }
    found if found
  end

  def next_generation
    self.class.new(survivors, @tests)
  end

  def count
    @programs.count
  end

  def alive?
    @programs.any?
  end

  def survivors
    @survivors ||= programs_with_fitness.select { |(_, f)|
      0 < f && f >= survival_threshold
    }.sort_by { |(_, f)| f }.reverse.map(&:first)
  end

  def survival_threshold
    @survival_threshold ||= fitnesses.reduce(:+) / fitnesses.count.to_f # average
  end

  private

  def programs_with_fitness
    @programs_with_fitness ||= @programs.map { |p| [p, p.fitness(@tests)] }
  end

  def fitnesses
    @fitnesses ||= programs_with_fitness.map(&:last)
  end
end

class Revolver
  def initialize
    @tests = []
  end

  def return_value_should(test)
    @tests << test
    self
  end

  def go!
    g = Generation.random(@tests)
    until winner = g.evolve_until_winner
      puts "Family tree extinguished. Spawning new random population."
      g = Generation.random(@tests)
    end

    if winner
      puts "Found program!"
      puts winner.source.inspect
      result = winner.run
      puts "# => #{result}"
    else

      puts "Found no programs."
    end
  end
end
