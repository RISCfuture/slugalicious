require 'spec_helper'

describe Slug do
  before :each do
    @record = Factory(:user)
    Slug.delete_all
  end

  describe "validation" do
    it "should not allow an active slug to be created if one already exists" do
      Factory(:slug, sluggable: @record)
      slug = Factory.build(:slug, sluggable: @record)
      slug.should_not be_valid
      slug.errors[:active].should_not be_empty
    end

    it "should not allow a slug to be made active if one already exists" do
      Factory(:slug, sluggable: @record)
      slug = Factory(:slug, sluggable: @record, active: false)
      slug.active = true
      slug.should_not be_valid
      slug.errors[:active].should_not be_empty
    end

    it "should allow an active slug to be created if none exists" do
      slug = Factory.build(:slug, sluggable: @record)
      slug.should be_valid
    end

    it "should allow a slug to be made active if none exists" do
      slug = Factory(:slug, sluggable: @record, active: false)
      slug.active = true
      slug.should be_valid
    end

    it "should allow an inactive slug to be modified if the active field is not changing" do
      Factory(:slug, sluggable: @record)
      slug = Factory(:slug, sluggable: @record, active: false)
      slug.scope = 'test'
      slug.should be_valid
    end
  end

  describe "#activate!" do
    it "should mark the slug as active" do
      slug = Factory(:slug, sluggable: Factory(:user), active: false)
      slug.activate!
      slug.should be_active
    end

    it "should deactivate all the record's other slugs" do
      record = Factory(:user)
      s1 = Slug.for(record).first
      s2 = Factory(:slug, sluggable: record, active: false)
      s3 = Factory(:slug, sluggable: record, active: false)

      slug = Factory(:slug, sluggable: record, active: false)
      slug.activate!

      s1.reload.should_not be_active
      s2.reload.should_not be_active
      s3.reload.should_not be_active
    end
  end
end
