# frozen_string_literal: true

# Base class for all view components in the application.
#
# Provides a declarative `prop` DSL for defining component properties
# with support for required/optional props, defaults, type coercion,
# and automatic attr_reader generation.
#
# Any keyword arguments not declared as props are passed through
# to `html_options` for use as HTML attributes in templates.
#
# @example Basic usage
#   class MyComponent < ApplicationComponent
#     prop :title
#     prop :subtitle, optional: true
#     prop :count,    type: proc(&:to_i), default: -> { 0 }
#     prop :status,   type: proc(&:to_sym)
#   end
#
class ApplicationComponent < ViewComponent::Base

  class << self

    # Declares a component prop with optional configuration.
    #
    # Automatically generates a public +attr_reader+ for the prop.
    #
    # @param name [Symbol] the prop name
    # @param opts [Hash] prop options
    # @option opts [Boolean] :optional when +true+, the prop is not required
    # @option opts [Proc] :default a callable that returns the default value
    # @option opts [Proc] :type a callable used to coerce the value (e.g. +proc(&:to_s)+)
    # @return [void]
    def prop(name, **opts)
      props << [name, opts]
      attr_reader name
    end

    # Returns the list of declared props for this component class.
    #
    # Props are inherited from the superclass via +dup+ so that
    # child classes can add their own without mutating the parent.
    #
    # @return [Array<Array(Symbol, Hash)>] list of +[name, opts]+ tuples
    def props
      if superclass.respond_to?(:props)
        @props ||= superclass.props.dup
      else
        @props ||= []
      end
    end

  end

  # @return [Hash] any keyword arguments not declared as props
  attr_reader :html_options

  # Initializes the component by processing declared props from the
  # given keyword arguments.
  #
  # Props are validated for presence, resolved with defaults and type
  # coercion, and set as instance variables. Any remaining keyword
  # arguments are stored in +@html_options+.
  #
  # @param attrs [Hash] keyword arguments matching declared props and/or HTML attributes
  # @raise [ArgumentError] if a required prop is missing
  def initialize(**attrs)
    super()

    self.class.props.each do |name, opts|
      validate_presence!(name, opts, attrs)
      next unless assign?(name, opts, attrs)

      instance_variable_set("@#{name}", resolve_value(name, opts, attrs))
    end

    @html_options = attrs.except(*prop_names)
  end

  # Returns the component's content, falling back to +@_text+.
  #
  # @return [String, nil]
  def content
    super || @_text
  end

  private

  # Raises an error if a required prop is missing from the attributes.
  #
  # A prop is considered required when it is not marked as +optional+
  # and has no +default+ defined.
  #
  # @param name [Symbol] the prop name
  # @param opts [Hash] the prop options
  # @param attrs [Hash] the keyword arguments passed to +initialize+
  # @raise [ArgumentError] if the prop is required but not provided
  # @return [void]
  def validate_presence!(name, opts, attrs)
    return if opts[:optional]
    return if opts[:default]
    return if attrs.key?(name)

    raise ArgumentError, "prop #{name} is required"
  end

  # Determines whether a prop should be assigned an instance variable.
  #
  # A prop is assignable if it has a default or was explicitly passed.
  #
  # @param name [Symbol] the prop name
  # @param opts [Hash] the prop options
  # @param attrs [Hash] the keyword arguments passed to +initialize+
  # @return [Boolean]
  def assign?(name, opts, attrs)
    opts[:default] || attrs.key?(name)
  end

  # Resolves the final value for a prop by applying the default
  # and type coercion if configured.
  #
  # @param name [Symbol] the prop name
  # @param opts [Hash] the prop options
  # @param attrs [Hash] the keyword arguments passed to +initialize+
  # @return [Object] the resolved prop value
  def resolve_value(name, opts, attrs)
    value = attrs[name]
    value = opts[:default].call if value.nil? && opts[:default]
    coerce(value, opts[:type])
  end

  # Coerces a value using the given type callable.
  #
  # Returns the value unchanged if no type is provided or the value is +nil+.
  #
  # @param value [Object] the value to coerce
  # @param type [Proc, nil] a callable that performs the coercion
  # @return [Object] the coerced value
  def coerce(value, type)
    return value unless type && value

    type.call(value)
  end

  # Returns the names of all declared props for this component class.
  #
  # @return [Array<Symbol>]
  def prop_names
    self.class.props.map(&:first)
  end

end
