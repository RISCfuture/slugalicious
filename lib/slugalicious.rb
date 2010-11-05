require 'slugalicious_generator'
require 'stringex'

# Adds the @slugged@ method to an @ActiveRecord::Base@ subclass. You can then
# call this method to add slugging support to your model. See the
# {ClassMethods#slugged} method for more details.
#
# @example Basic example of a slugged model
#  class Widget < ActiveRecord::Base
#    include Slugalicious
#    slugged :title
#  end

module Slugalicious
  extend ActiveSupport::Concern

  # The maximum length of a slug.
  MAX_SLUG_LENGTH = 126

  included do
    extend ActiveSupport::Memoizable
    memoize :slug, :active_slug?
    alias_method :to_param, :slug_with_path
    has_many :slugs, as: :sluggable
  end

  # Methods added to the class when this module is included.

  module ClassMethods
    
    # Locates a record matching a given slug.
    #
    # @param [String] slug The slug to locate.
    # @param [String] scope The scope to search in (for use with scoped-unique
    #   slugs). This should be a string equal to the portion of the URL path
    #   preceding the slug.
    # @return [ActiveRecord::Base] The object with that slug.
    # @raise [ActiveRecord::RecordNotFound] If no object with that slug is
    #   found.

    def find_from_slug(slug, scope=nil)
      Slug.from_slug(self, scope, slug).first.try(:sluggable) || raise(ActiveRecord::RecordNotFound)
    end

    # Locates a record from a given path, that consists of a slug and its scope,
    # as would appear in a URL path component.
    #
    # @param [String] path The scope and slug concatenated together.
    # @return [ActiveRecord::Base] The object with that slug.
    # @raise [ActiveRecord::RecordNotFound] If no object with that slug is
    #   found.

    def find_from_slug_path(path)
      slug = path.split('/').last
      scope = path[0..(-(slug.size + 1))]
      find_from_slug slug, scope
    end

    protected
    
    # Call this method to indicate that your model uses slugging. Pass a list of
    # *slug generators*: either symbols (method names) or procs that return
    # strings. These strings will be used to generate the slug. You must pass at
    # least one generator. If you pass more than one, the first one that returns
    # a unique slug will be used.
    #
    # The generator does not need to sanitize or parameterize its output; the
    # @:slugifier@ option can be used to override the default parameterization.
    #
    # In the event that no generator returns a unique slug, the slug returned by
    # the last generator will have the ID of the record appended to it. The ID
    # and the slug will be separated by the @:id_separator@ option (semicolon by
    # default). _This_ slug is hopefully unique, because if not, an exception is
    # raised.
    #
    # Slugs are automatically generated before validation and updated when
    # necessary.
    #
    # h2. Scopes
    #
    # You can scope your slugs to certain URL subpaths using the @:scope@
    # option. The @:scope:@ option takes a method name or a @Proc@ that, when
    # run, returns a string that scopes the uniqueness constraint of a slug.
    # Rather than being globally unique, the slug must only be unique among
    # other slugs that share the same scope.
    #
    # *Important note:* The method or @Proc@ that you use for the @:scope@
    # option should return the portion of the URL preceding the slug, _slash
    # included_. Let's say you have slugged your @User@ model's @login@ field,
    # and you have two scopes: customers and merchants. In that case, you would
    # want the @:scope@ method/proc to return either "clients/" or "merchants/".
    #
    # The string returned by the @:scope@ option will be used to build the full
    # URL to an object. If you have a client @User@ with login "fancylad", a
    # call to @to_param@ will return "clients/fancyland". The scope portion of
    # that URL path is used un-sanitized, un-escaped, and un-processed. It is
    # therefore up to _you_ to ensure your scopes are valid URL strings, using
    # say @String#to_url@ (included as part of this gem).
    #
    # @overload slugged(generator, ..., options={})
    #   @param [Proc, Symbol] generator If it's a @Symbol@, indicates a method
    #     that will be called that will return a @String@ to be used for the
    #     slug.
    #   @param [Hash] options Additonal options that control slug generation.
    #   @option options [Proc] :slugifier (&:to_url) A proc that, when given a
    #     string, produces a URL-safe slugged version of that string.
    #   @option options [String] :id_separator (';') A separator to be used in
    #     the "last-resort" slug between the slug and the model ID. This should
    #     be an URL-safe character that would never be produced by your
    #     slugifier.
    #   @option options [Symbol, Proc] :scope A method name or @Proc@ to run
    #     (receives the object being slugged) that returns a string. Slugs must
    #     be unique across all objects for which this method/proc returns the
    #     same value. If not provided, slugs must be globally unique for this
    #     model. The string returned should be equal to the portion of the URL
    #     path that precedes the slug.
    #   @option options [Array<String>, String] :blacklist ([ 'new', 'edit', 'delete' ])
    #     A list of slugs that are disallowed. You would use this to prevent
    #     slugs from sharing the same name as actions in your resource
    #     controller.
    # @raise [ArgumentError] If no generators are provided.

    def slugged(*slug_procs)
      options = slug_procs.extract_options!
      raise ArgumentError, "Must provide at least one field or proc to slug" if slug_procs.empty?

      class_inheritable_array :_slug_procs, :_slug_blacklist
      class_inheritable_accessor :_slugifier, :_slug_id_separator, :_slug_scope

      self._slug_procs = slug_procs.map { |slug_proc| slug_proc.kind_of?(Symbol) ? ->(obj) { obj.send(slug_proc) } : slug_proc }
      self._slugifier = options[:slugifier] || ->(string) { string.to_url }
      self._slug_id_separator = options[:id_separator] || ';'
      self._slug_scope = if options[:scope].kind_of?(Symbol) then
                           ->(record) { record.send(options[:scope]).to_s }
                         elsif options[:scope].kind_of?(Proc) then
                           options[:scope]
                         elsif options[:scope] then
                           raise ArgumentError, ":scope must be a symbol or proc"
                         end
      self._slug_blacklist = Array.wrap(options[:blacklist] || %w( new edit delete ))

      after_save :make_slug
    end
  end

  # Methods added to instances when this module is included.

  module InstanceMethods

    # @return [String, nil] The slug for this object, or @nil@ if none has been
    #   assigned.

    def slug
      (slugs.loaded? ? slugs.detect(&:active?) : slugs.active.first).try(:slug)
    end

    # @return [String, nil] The full slug and path for this object, with scope
    #   included, or @nil@ if none has been assigned.

    def slug_with_path
      slug = slugs.loaded? ? slugs.detect(&:active) : slugs.active.first
      if slug then
        slug.scope.to_s + slug.slug
      else
        nil
      end
    end

    # @param [String] slug A slug for this object.
    # @return [true, false, nil] @true@ if the slug is the currently active one
    #   (should not redirect), @false@ if it's inactive (should redirect), and
    #   @nil@ if it's not a known slug for the object (should 404).

    def active_slug?(slug)
      slug = if slugs.loaded? then
               slugs.detect { |s| s.slug.downcase == slug.downcase }
             else
               slugs.where(slug: slug).first
             end
      if slug then
        slug.active?
      else
        nil
      end
    end

    def make_slug
      slugs_in_use = if slugs.loaded? then
                       slugs.map(&:slug)
                     else
                       slugs.select(:slug).all.map(&:slug)
                     end

      # grab a list of all potential slugs derived from the generators
      potential_slugs = self.class._slug_procs.map { |slug_proc| slug_proc[self] }.
        compact.
        map { |slug| self.class._slugifier[slug] }.
        map { |slug| slug[0, MAX_SLUG_LENGTH] }
      raise "All slug generators returned nil for #{self.inspect}" if potential_slugs.empty?
      # include the last-resort slug, trimmed for length
      last_resort_append = "#{self.class._slug_id_separator}#{id}"
      potential_slugs << "#{potential_slugs.first[0, [ 1, MAX_SLUG_LENGTH - last_resort_append.length ].max]}#{last_resort_append}"[0, MAX_SLUG_LENGTH]
      # subtract out blacklisted slugs
      potential_slugs -= self.class._slug_blacklist
      
      # if one of these slugs is already in use, we don't need to change the slug
      # instead, activate the one of highest prioirty and we're done
      valid_slugs_in_use = potential_slugs & slugs_in_use
      unless valid_slugs_in_use.empty?
        Slug.transaction do
          slugs.update_all(active: false)
          slugs.where(slug: valid_slugs_in_use.first).update_all(active: true)
        end
        return
      end

      Slug.transaction do
        # grab a list of all the slugs we can't use
        scope = Slug.select(:slug).where(sluggable_type: self.class.to_s, slug: potential_slugs)
        if self.class._slug_scope then
          scope = scope.where(scope: self.class._slug_scope[self])
        end
        taken_slug_objects = scope.all

        # subtract them out from all the potential slugs to make the available slugs
        available_slugs = potential_slugs - taken_slug_objects.map(&:slug)
        # no slugs available? nothing much else we can do
        raise "Couldn't find a slug for #{self.inspect}; tried #{potential_slugs.join(', ')}" if available_slugs.empty?
        
        slugs.update_all(active: false)
        Slug.create!(sluggable: self,
                     slug: available_slugs.first,
                     active: true,
                     scope: self.class._slug_scope.try(:call, self))
      end

      unmemoize_all
    end
  end
end
