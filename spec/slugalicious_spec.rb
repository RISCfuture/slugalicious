require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Slugalicious do
  before :each do
    @model = Class.new
    @model.send :include, ActiveModel::Validations
    @model.send :include, ActiveModel::Validations::Callbacks
    @model.send :include, ActiveRecord::Callbacks
    @model.send :include, ActiveRecord::Validations
    @model.stub!(:has_many)
    @model.send :include, Slugalicious
  end

  describe "#slugged" do
    it "should raise an error if no generators are given" do
      expect { @model.send(:slugged, { options: 'here' }) }.to raise_error(ArgumentError)
    end
  end

  describe "#to_param" do
    it "should return the slug" do
      user = Factory(:user)
      user.slug.should_not be_nil
      user.to_param.should eql(user.slug)
    end

    it "should return the full slug path when scoped" do
      User._slug_procs.clear
      User.send :slugged, :first_name, scope: :last_name
      
      user = Factory(:user, last_name: 'test/')
      user.to_param.should eql('test/doctor')
    end
  end

  context "slug generation" do
    before :each do
      User._slug_procs.clear
      User._slug_blacklist.clear
    end

    it "should set the slug according to the generator and apply the slugifier" do
      User.send :slugged, :first_name
      object = Factory(:user, first_name: "Sancho", last_name: "Sample")
      object.slug.should eql("sancho")
    end

    it "should generate from a proc as well as a symbol" do
      User.send :slugged, ->(person) { "#{person.first_name} #{person.last_name}" }
      object = Factory(:user, first_name: "Foo", last_name: "bar")
      object.slug.should eql("foo-bar")
    end

    it "should give priority to the first non-nil slug" do
      User.send :slugged, :gender, :last_name
      object = Factory(:user, gender: nil, last_name: "Bar")
      object.slug.should eql("bar")
    end
    
    it "should not create a new slug if an existing one matches" do
      User.send :slugged, :first_name, :last_name
      object = Factory(:user, first_name: 'Foo', last_name: "Bar")
      object.slug.should eql("foo")
      other_slug = Factory(:slug, slug: 'bar', sluggable: object, active: false)
      
      object.update_attribute :last_name, 'baz'
      object.slug.should eql("foo")
      other_slug.reload.active.should be_false
    end

    it "should ignore slugs from other models" do
      User.send :slugged, :first_name, :last_name
      Factory(:abuser, last_name: 'Foo').slug.should eql('foo')
      Factory(:user, first_name: 'Foo', last_name: 'Foo').slug.should eql('foo')
    end

    it "should use the last-resort generator if nothing else is unique" do
      User.send :slugged, :first_name, :last_name
      Factory(:user, first_name: 'Foo', last_name: 'Bar').slug.should eql('foo')
      Factory(:user, first_name: 'Foo', last_name: 'Bar').slug.should eql('bar')
      user = Factory(:user, first_name: 'Foo', last_name: 'Bar')
      user.slug.should eql("foo;#{user.id}")
    end

    it "should raise an error if all generators return nil" do
      User.send :slugged, :gender, :birthdate
      -> { Factory(:user, gender: nil, birthdate: nil) }.should raise_error
    end
    
    it "should use the first non-nil slug for the last-resort generator" do
      User.send :slugged, :gender, :first_name, :last_name
      Factory(:user, first_name: 'Foo', last_name: 'Bar', gender: nil)
      Factory(:user, first_name: 'Foo', last_name: 'Bar', gender: nil)
      user = Factory(:user, first_name: 'Foo', last_name: 'Bar', gender: nil)
      user.slug.should eql("foo;#{user.id}")
    end

    it "should use a custom id separator if given" do
      User.send :slugged, :first_name, :last_name, id_separator: ':'
      Factory(:user, first_name: 'Foo', last_name: 'Bar')
      Factory(:user, first_name: 'Foo', last_name: 'Bar')
      user = Factory(:user, first_name: 'Foo', last_name: 'Bar')
      user.slug.should eql("foo:#{user.id}")
    end
    
    it "should avoid blacklisted slugs" do
      User.send :slugged, :first_name, :last_name
      Factory(:user, first_name: 'New', last_name: 'Bar').slug.should eql('bar')
    end

    it "should use a custom blacklist" do
      User.send :slugged, :first_name, :last_name, blacklist: %w( foo bar )
      Factory(:user, first_name: 'Foo', last_name: 'Baz').slug.should eql('baz')
    end

    it "should wrap the blacklist array" do
      User.send :slugged, :first_name, :last_name, blacklist: 'foo'
      Factory(:user, first_name: 'Foo', last_name: 'Baz').slug.should eql('baz')
    end
    
    it "should only search for available slugs inside the scope if given" do
      User.send :slugged, :first_name, :last_name, scope: :callsign

      Factory(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'One').slug.should eql('foo')
      Factory(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'One').slug.should eql('baz')
      Factory(:user, first_name: 'Boo', last_name: 'Bar', callsign: 'One').slug.should eql('boo')
      
      Factory(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'Two').slug.should eql('foo')
      Factory(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'Two').slug.should eql('baz')
    end

    it "should accept a proc for a scope" do
      User.send :slugged, :first_name, :last_name, scope: ->(object) { object.callsign[0] }

      Factory(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'One').slug.should eql('foo')
      Factory(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'Only').slug.should eql('baz')
      Factory(:user, first_name: 'Boo', last_name: 'Bar', callsign: 'Ocho').slug.should eql('boo')

      Factory(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'Two').slug.should eql('foo')
      Factory(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'Tres').slug.should eql('baz')
    end

    it "should enforce a maximum length of 126 characters" do
      User.send :slugged, :first_name

      user = Factory(:user)
      user.first_name = 'A'*500
      user.save(validate: false)
      user.slug.should eql('a'*126)
    end

    it "should shorten left of the ID separator" do
      User.send :slugged, :first_name

      user1 = Factory(:user)
      user1.first_name = 'A'*500
      user1.save(validate: false)

      user2 = Factory(:user)
      user2.first_name = 'A'*500
      user2.save(validate: false)

      user2.slug.size.should eql(126)
      user2.slug.should match(/^a+;#{user2.id}$/)
    end

    it "should raise an error if no unique slugs are available" do
      old_length = Slugalicious::MAX_SLUG_LENGTH
      Slugalicious::MAX_SLUG_LENGTH = 1

      User.send :slugged, ->(object) { 'f' }, blacklist: 'f'
      -> { Factory(:user, first_name: 'Foo', last_name: 'Bar') }.should raise_error
      
      Slugalicious::MAX_SLUG_LENGTH = old_length
    end
  end

  describe "#find_from_slug" do
    it "should return a Slug object for a slug" do
      User.send :slugged, :first_name, :last_name
      user1 = Factory(:user, first_name: "FN1", last_name: "LN1")
      User.find_from_slug('fn1').should eql(user1)
    end

    it "should exclude slugs of other models" do
      User.send :slugged, :first_name, :last_name
      user1 = Factory(:user, first_name: "FN1", last_name: "LN1")
      Factory(:abuser, first_name: 'FN1')
      User.find_from_slug('fn1').should eql(user1)
    end

    it "should locate an object within a given scope" do
      User.send :slugged, :first_name, scope: :last_name
      user1 = Factory(:user, first_name: "FN1", last_name: "LN1")
      user2 = Factory(:user, first_name: "FN1", last_name: "LN2")
      User.find_from_slug('fn1', 'LN1').should eql(user1)
      User.find_from_slug('fn1', 'LN2').should eql(user2)
    end

    it "should return nil if the slug does not exist" do
      User.find_from_slug('nonexist').should be_nil
    end

    it "should return nil if the slug does not exist in scope" do
      User.send :slugged, :first_name, scope: :last_name
      Factory(:user, first_name: "FN1", last_name: "LN1")
      Factory(:user, first_name: "FN2", last_name: "LN2")
      User.find_from_slug('fn2', 'ln1').should be_nil
    end

    it "should find inactive slugs" do
      User.send :slugged, :first_name
      user = Factory(:user, first_name: 'New')
      Factory(:slug, sluggable: user, slug: 'old', active: false)
      User.find_from_slug('old').should eql(user)
    end
  end

  describe "#find_from_slug!" do
    it "should return a Slug object for a slug" do
      User.send :slugged, :first_name, :last_name
      user1 = Factory(:user, first_name: "FN1", last_name: "LN1")
      User.find_from_slug!('fn1').should eql(user1)
    end

    it "should raise ActiveRecord::RecordNotFound if the slug does not exist" do
      -> { User.find_from_slug!('nonexist') }.should raise_error(ActiveRecord::RecordNotFound)
    end

    it "should raise ActiveRecord::RecordNotFound if the slug does not exist in scope" do
      User.send :slugged, :first_name, scope: :last_name
      Factory(:user, first_name: "FN1", last_name: "LN1")
      Factory(:user, first_name: "FN2", last_name: "LN2")
      -> { User.find_from_slug!('fn2', 'ln1') }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#find_from_slug_path" do
    it "should call #find_from_slug with the slug and no scope for unscoped models" do
      User.send :slugged, :first_name
      User.should_receive(:find_from_slug).once.with("test", '')
      User.find_from_slug_path("test")
    end

    it "should call #find_from_slug with the slug and scope for scoped models" do
      User.send :slugged, :first_name, scope: :last_name
      User.should_receive(:find_from_slug).once.with("test", "path/to/")
      User.find_from_slug_path("path/to/test")
    end
  end
end
