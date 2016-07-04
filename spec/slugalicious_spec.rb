require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Slugalicious do
  before :each do
    @model = Class.new
    @model.send :include, ActiveModel::Validations
    @model.send :include, ActiveModel::Validations::Callbacks
    @model.send :include, ActiveRecord::Callbacks
    @model.send :include, ActiveRecord::Validations
    allow(@model).to receive(:has_many)
    @model.send :include, Slugalicious
  end

  describe "#slugged" do
    it "should raise an error if no generators are given" do
      expect { @model.send(:slugged, { options: 'here' }) }.to raise_error(ArgumentError)
    end
  end

  describe "#to_param" do
    it "should return the slug" do
      user = FactoryGirl.create(:user)
      expect(user.slug).not_to be_nil
      expect(user.to_param).to eql(user.slug)
    end

    it "should return the full slug path when scoped" do
      User._slug_procs.clear
      User.send :slugged, :first_name, scope: :last_name
      
      user = FactoryGirl.create(:user, last_name: 'test/')
      expect(user.to_param).to eql('test/doctor')
    end
  end

  context "slug generation" do
    before :each do
      User._slug_procs.clear
      User._slug_blacklist.clear
    end

    it "should set the slug according to the generator and apply the slugifier" do
      User.send :slugged, :first_name
      object = FactoryGirl.create(:user, first_name: "Sancho", last_name: "Sample")
      expect(object.slug).to eql("sancho")
    end

    it "should generate from a proc as well as a symbol" do
      User.send :slugged, ->(person) { "#{person.first_name} #{person.last_name}" }
      object = FactoryGirl.create(:user, first_name: "Foo", last_name: "bar")
      expect(object.slug).to eql("foo-bar")
    end

    it "should give priority to the first non-nil slug" do
      User.send :slugged, :gender, :last_name
      object = FactoryGirl.create(:user, gender: nil, last_name: "Bar")
      expect(object.slug).to eql("bar")
    end
    
    it "should not create a new slug if an existing one matches" do
      User.send :slugged, :first_name, :last_name
      object = FactoryGirl.create(:user, first_name: 'Foo', last_name: "Bar")
      expect(object.slug).to eql("foo")
      other_slug = FactoryGirl.create(:slug, slug: 'bar', sluggable: object, active: false)
      
      object.update_attribute :last_name, 'baz'
      expect(object.slug).to eql("foo")
      expect(other_slug.reload).not_to be_active
    end

    it "should ignore slugs from other models" do
      User.send :slugged, :first_name, :last_name
      expect(FactoryGirl.create(:abuser, last_name: 'Foo').slug).to eql('foo')
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Foo').slug).to eql('foo')
    end

    it "should use the last-resort generator if nothing else is unique" do
      User.send :slugged, :first_name, :last_name
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar').slug).to eql('foo')
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar').slug).to eql('bar')
      user = FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar')
      expect(user.slug).to eql("foo;#{user.id}")
    end

    it "should raise an error if all generators return nil" do
      User.send :slugged, :gender, :callsign
      expect { FactoryGirl.create(:user, gender: nil, callsign: nil) }.to raise_error(/All slug generators returned nil/)
    end
    
    it "should use the first non-nil slug for the last-resort generator" do
      User.send :slugged, :gender, :first_name, :last_name
      FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', gender: nil)
      FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', gender: nil)
      user = FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', gender: nil)
      expect(user.slug).to eql("foo;#{user.id}")
    end

    it "should use a custom id separator if given" do
      User.send :slugged, :first_name, :last_name, id_separator: ':'
      FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar')
      FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar')
      user = FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar')
      expect(user.slug).to eql("foo:#{user.id}")
    end
    
    it "should avoid blacklisted slugs" do
      User.send :slugged, :first_name, :last_name
      expect(FactoryGirl.create(:user, first_name: 'New', last_name: 'Bar').slug).to eql('bar')
    end

    it "should use a custom blacklist" do
      User.send :slugged, :first_name, :last_name, blacklist: %w( foo bar )
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Baz').slug).to eql('baz')
    end

    it "should wrap the blacklist array" do
      User.send :slugged, :first_name, :last_name, blacklist: 'foo'
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Baz').slug).to eql('baz')
    end
    
    it "should only search for available slugs inside the scope if given" do
      User.send :slugged, :first_name, :last_name, scope: :callsign

      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'One').slug).to eql('foo')
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'One').slug).to eql('baz')
      expect(FactoryGirl.create(:user, first_name: 'Boo', last_name: 'Bar', callsign: 'One').slug).to eql('boo')
      
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'Two').slug).to eql('foo')
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'Two').slug).to eql('baz')
    end

    it "should accept a proc for a scope" do
      User.send :slugged, :first_name, :last_name, scope: ->(object) { object.callsign[0] }

      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'One').slug).to eql('foo')
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'Only').slug).to eql('baz')
      expect(FactoryGirl.create(:user, first_name: 'Boo', last_name: 'Bar', callsign: 'Ocho').slug).to eql('boo')

      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar', callsign: 'Two').slug).to eql('foo')
      expect(FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Baz', callsign: 'Tres').slug).to eql('baz')
    end

    it "should enforce a maximum length of 126 characters" do
      User.send :slugged, :first_name

      user = FactoryGirl.create(:user)
      user.first_name = 'A'*500
      user.save(validate: false)
      expect(user.slug).to eql('a'*126)
    end

    it "should shorten left of the ID separator" do
      User.send :slugged, :first_name

      user1 = FactoryGirl.create(:user)
      user1.first_name = 'A'*500
      user1.save(validate: false)

      user2 = FactoryGirl.create(:user)
      user2.first_name = 'A'*500
      user2.save(validate: false)

      expect(user2.slug.size).to eql(126)
      expect(user2.slug).to match(/^a+;#{user2.id}$/)
    end

    it "should raise an error if no unique slugs are available" do
      old_length = Slugalicious::MAX_SLUG_LENGTH
      Slugalicious::MAX_SLUG_LENGTH = 1

      User.send :slugged, ->(object) { 'f' }, blacklist: 'f'
      expect { FactoryGirl.create(:user, first_name: 'Foo', last_name: 'Bar') }.to raise_error(/Couldn't find a slug/)
      
      Slugalicious::MAX_SLUG_LENGTH = old_length
    end
  end

  describe "#find_from_slug" do
    it "should return a Slug object for a slug" do
      User.send :slugged, :first_name, :last_name
      user1 = FactoryGirl.create(:user, first_name: "FN1", last_name: "LN1")
      expect(User.find_from_slug('fn1')).to eql(user1)
    end

    it "should exclude slugs of other models" do
      User.send :slugged, :first_name, :last_name
      user1 = FactoryGirl.create(:user, first_name: "FN1", last_name: "LN1")
      FactoryGirl.create(:abuser, first_name: 'FN1')
      expect(User.find_from_slug('fn1')).to eql(user1)
    end

    it "should locate an object within a given scope" do
      User.send :slugged, :first_name, scope: :last_name
      user1 = FactoryGirl.create(:user, first_name: "FN1", last_name: "LN1")
      user2 = FactoryGirl.create(:user, first_name: "FN1", last_name: "LN2")
      expect(User.find_from_slug('fn1', 'LN1')).to eql(user1)
      expect(User.find_from_slug('fn1', 'LN2')).to eql(user2)
    end

    it "should return nil if the slug does not exist" do
      expect(User.find_from_slug('nonexist')).to be_nil
    end

    it "should return nil if the slug does not exist in scope" do
      User.send :slugged, :first_name, scope: :last_name
      FactoryGirl.create(:user, first_name: "FN1", last_name: "LN1")
      FactoryGirl.create(:user, first_name: "FN2", last_name: "LN2")
      expect(User.find_from_slug('fn2', 'ln1')).to be_nil
    end

    it "should find inactive slugs" do
      User.send :slugged, :first_name
      user = FactoryGirl.create(:user, first_name: 'New')
      FactoryGirl.create(:slug, sluggable: user, slug: 'old', active: false)
      expect(User.find_from_slug('old')).to eql(user)
    end
  end

  describe "#find_from_slug!" do
    it "should return a Slug object for a slug" do
      User.send :slugged, :first_name, :last_name
      user1 = FactoryGirl.create(:user, first_name: "FN1", last_name: "LN1")
      expect(User.find_from_slug!('fn1')).to eql(user1)
    end

    it "should raise ActiveRecord::RecordNotFound if the slug does not exist" do
      expect { User.find_from_slug!('nonexist') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should raise ActiveRecord::RecordNotFound if the slug does not exist in scope" do
      User.send :slugged, :first_name, scope: :last_name
      FactoryGirl.create(:user, first_name: "FN1", last_name: "LN1")
      FactoryGirl.create(:user, first_name: "FN2", last_name: "LN2")
      expect { User.find_from_slug!('fn2', 'ln1') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#find_from_slug_path" do
    it "should call #find_from_slug with the slug and no scope for unscoped models" do
      User.send :slugged, :first_name
      expect(User).to receive(:find_from_slug).once.with("test", '')
      User.find_from_slug_path("test")
    end

    it "should call #find_from_slug with the slug and scope for scoped models" do
      User.send :slugged, :first_name, scope: :last_name
      expect(User).to receive(:find_from_slug).once.with("test", "path/to/")
      User.find_from_slug_path("path/to/test")
    end
  end
end
