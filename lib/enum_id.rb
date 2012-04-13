# Defines an enumerated field (stored as an integral id).
# The field is defined by its name (which must be the column name without the _id suffix),
# and a hash which maps the id valid values of the field to symbolic constants.
# The hash can also contain options with symbolic keys; currently the only valid option is
# :required which checks for non-nil values at validation; if a value other than true is
# assigned to it, it should be a hash with options that will be relayed to validates_presence_of
class ActiveRecord::Base

  def self.enum_id(name, options_and_enum_values)
    options_and_enum_values = options_and_enum_values.group_by{|k,v| k.kind_of?(Integer) ? :values : :options}
    options = (options_and_enum_values[:options]||[]).to_h
    symbols_map = (options_and_enum_values[:values]||[]).to_h
    ids_map = symbols_map.invert

    required = options[:required]

    name_id = :"#{name}_id"
    symbols_const = :"ENUM_ID_#{name}_SYMBOLS"
    ids_const = :"ENUM_ID_#{name}_IDS"

    const_set symbols_const, symbols_map
    const_set ids_const, ids_map

    model_class = self

    # Instance methods

    # Access the enumerated value as a symbol.
    define_method name do
      # #{model_class.name}.#{name}(#{name}_id)
      model_class.send name, self.send(name_id)
    end

    # Assigns the enumerated value as a symbol or id (integer)
    define_method :"#{name}=" do |st|
      # self.#{name}_id = #{model_class.name}.#{name}_id(st)
      self.send :"#{name_id}=", model_class.send(name_id, st)
    end

    # Access the human-name of the (symbolic or integral id) value (translated)
    define_method :"#{name}_name" do
      # #{model_class.name}.#{name}_name(#{name}_id)
      model_class.send :"#{name}_name", self.send(name_id)
    end

    symbols_map.values.each do |stat|
      define_method :"#{stat}?" do
        send(name) == stat
      end
    end

    # Class methods

    model_metaclass = class << model_class; self; end
    model_metaclass.instance_eval do
      define_method name do |id|
        # id && (#{symbols_const}[id.to_i] || raise("Invalid status id: #{id}"))
        id && (symbols_map[id.to_i] || raise("Invalid #{name} id: #{id}"))
      end

      define_method name_id do |st|
        st && if st.kind_of?(Integer)
          raise "Invalid #{name} id: #{st}" unless send(:"#{name}_ids").include?(st)
          st
        elsif st.kind_of?(Symbol)
          ids_map[st.to_sym] || raise("Invalid #{name}: #{st.inspect}")
        else
          raise TypeError,"Integer or Symbol argument expected (got a #{st.class.name})."
        end
      end

      define_method :"#{name}_symbol" do |st|
        st && (st.kind_of?(Integer) ? send(name, st) : st.to_sym)
      end

      define_method :"#{name}_name" do |st|
        st = send(:"#{name}_symbol", st)
        st && I18n.t("enum_id.#{model_class.name.underscore}.#{name}.#{st}")
      end

      define_method :"#{name}_ids" do
        symbols_map.keys.sort
      end

      define_method :"#{name}_symbols" do
        send(:"#{name}_ids").map{|id| send(:"#{name}_symbol", id)}
      end
    end

    # Define validations
    if required == true
      validates_inclusion_of name_id, :in=>model_class.send(:"#{name}_ids")
    else
      validates_inclusion_of name_id, :in=>model_class.send(:"#{name}_ids")+[nil]
      validates_presence_of name_id, required if required
    end
  end

end
