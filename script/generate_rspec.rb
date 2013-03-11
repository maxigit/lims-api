# vi: ts=2:sts=2:et:sw=2
require 'json'

class Object
  def andand
    yield(self) if self
  end
end

class Hash
  def method_missing(name, *args)
    self[name.to_s].andand do |v|
      if block_given?
        yield(v)
      else 
        v
      end
    end
  end
end

def process_directory(directory_name, directories=[])
  Dir.entries("#{directory_name}").sort { |a, b| a.to_i <=> b.to_i }.each do |name|
    full_name = File.join(directory_name, name)
    #puts "processing #{full_name}"

    case
    when /^\./ =~ name
      next
    when File.directory?(full_name)
      yield name if block_given?
      process_directory(full_name, directories + [name])
    when /.*\.json\z/ =~ name
      process_file(full_name, directories)
    end

  end
end

def create_directory(directories)
  return if directories == []
  FileUtils.mkdir_p(File.join(directories))
end


def title(basename)
  basename.sub(/^\d+_/, '')
end

def require_spec(filename, target)
  filename = $1 if filename =~ /spec\/(.*)\.rb/
    target.puts "require #{filename.inspect}"
end

def process_file(filename, directories=[])
  basename = File.basename(filename, '.*')
  target_file = File.join(directories, "#{basename}_spec.rb")
  h = JSON::parse(IO.read(filename))


  yield(filename, h) if block_given?

  create_directory(directories)
  helper_filename = helper_filename_for(directories)
  generate_helper_file(helper_filename, directories)
  File.open(target_file, 'w') do |target|
    h["title"] ||= title(basename)
    require_spec(helper_filename, target)
    h.post_require { |p| print_lines(target, p) }

    target.puts %Q{describe "#{h.title}" do}
    target.puts %Q{  include_context "use core context service"}

    # Depending of the shape of h, we generate one or many tests
    case 
    when h.is_a?(Array)
      h.each { |example| generate_http_request(example, target) }
    when h["method"], h["steps"] # final example
      generate_http_request(h, target)
    else # hash containing differents
      h.each do |k,v|
        # We only key which looks like a number
        # All the others are probably attributes used above
        next unless k =~ /\A\d+\z/
        generate_http_request(v, target)
      end
    end

    target.puts '  end'
    target.puts 'end'
  end
end                      

def helper_filename_for(directories)
  File.join(directories, 'spec_helper.rb')
end

def generate_helper_file(filename, directories)
  create_needed_file(filename) do |target|
    puts "generating #{filename}"
    parent_file = helper_filename_for(directories[0...-1])
    require_spec(parent_file, target)
    target.puts "# This file will be required by
# all file in this directory and subdirectory
    "
  end
end


  def create_needed_file(filename, &block)
    return if File.exist?(filename)

    File.open(filename, 'w') do |f|
      if block
        block.call(f)
      end
    end
  end
def print_lines(target, string)
        string.split(/[\r\n]/).each do |line|
          target.puts (block_given? ? yield(line) :  line)
        end
end

def generate_http_request(example, target)
  return unless example["method"] or example["steps"]

    example.description do |d|
      print_lines(target, d) { |line| "  # #{line}" }
    end
    target.puts %Q{  it "#{example.title || example["method"]}" do}

    example.setup do |s|
      print_lines(target, s) { |line| "    #{line}" }
    end
    target.puts
    ((example.header || []) + (example.response_header || [])).map do |h|
      key, value = h.split(/:\s/)
      target.puts "    header('#{key}', '#{value}')"
    end
    target.puts


    steps = example.steps || [example]
    steps.each do |step|
      target.puts %Q{    response = #{step["method"].downcase} #{[step.url.inspect, step.parameters.inspect].compact.join(', ')} }
        target.puts %Q{    response.status.should == #{step.status}}
        target.puts %Q{    response.body.should match_json #{step.response.gsub(/"\//, '"http://example.org/').inspect}}
    end
end

create_needed_file('spec/integrations/requests/spec_helper.rb') do |target|
  target.puts "require 'integrations/spec_helper'"
end
process_directory("spec/requests", ["spec/integrations/requests"]) do |directory|
  title = directory.sub(/\A\d+_/, '').split('_').map(&:capitalize).join(' ')
  print <<EOF
  --
    #{title}
--
EOF
end


