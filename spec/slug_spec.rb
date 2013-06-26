require 'spec_helper'

describe Slug do
  before :each do
    @record = FactoryGirl.create(:user)
    Slug.delete_all
  end

  context "[validation]" do
    it "should not allow an active slug to be created if one already exists" do
      FactoryGirl.create(:slug, sluggable: @record)
      slug = FactoryGirl.build(:slug, sluggable: @record)
      slug.should_not be_valid
      slug.errors[:active].should_not be_empty
    end

    it "should not allow a slug to be made active if one already exists" do
      FactoryGirl.create(:slug, sluggable: @record)
      slug = FactoryGirl.create(:slug, sluggable: @record, active: false)
      slug.active = true
      slug.should_not be_valid
      slug.errors[:active].should_not be_empty
    end

    it "should allow an active slug to be created if none exists" do
      slug = FactoryGirl.build(:slug, sluggable: @record)
      slug.should be_valid
    end

    it "should allow a slug to be made active if none exists" do
      slug = FactoryGirl.create(:slug, sluggable: @record, active: false)
      slug.active = true
      slug.should be_valid
    end

    it "should allow an inactive slug to be modified if the active field is not changing" do
      FactoryGirl.create(:slug, sluggable: @record)
      slug = FactoryGirl.create(:slug, sluggable: @record, active: false)
      slug.scope = 'test'
      slug.should be_valid
    end
  end

  describe "#activate!" do
    it "should mark the slug as active" do
      slug = FactoryGirl.create(:slug, sluggable: FactoryGirl.create(:user), active: false)
      slug.activate!
      slug.should be_active
    end

    it "should deactivate all the record's other slugs" do
      record = FactoryGirl.create(:user)
      s1 = Slug.for(record).first
      s2 = FactoryGirl.create(:slug, sluggable: record, active: false)
      s3 = FactoryGirl.create(:slug, sluggable: record, active: false)

      slug = FactoryGirl.create(:slug, sluggable: record, active: false)
      slug.activate!

      s1.reload.should_not be_active
      s2.reload.should_not be_active
      s3.reload.should_not be_active
    end
  end
  
  context "[caching]" do
    before :each do
      FactoryGirl.create(:slug, sluggable: @record)
    end
    
    it "should write the slug to the cache" do
      Rails.cache.read("Slug/User/#{@record.id}/slug").should be_nil
      Rails.cache.read("Slug/User/#{@record.id}/slug_with_path").should be_nil
      
      @record.slug
      @record.slug_with_path
      Rails.cache.read("Slug/User/#{@record.id}/slug").should eql(@record.slug)
      Rails.cache.read("Slug/User/#{@record.id}/slug_with_path").should eql(@record.slug_with_path)
    end
    
    it "should remove the cached slug when the slug is changed" do
      slug = FactoryGirl.create(:slug, sluggable: @record, active: false)
      slug.activate!
      Rails.cache.read("Slug/User/#{@record.id}/slug").should be_nil
      Rails.cache.read("Slug/User/#{@record.id}/slug_with_path").should be_nil
      
      @record.slug
      @record.slug_with_path
      Rails.cache.read("Slug/User/#{@record.id}/slug").should eql(@record.slug)
      Rails.cache.read("Slug/User/#{@record.id}/slug_with_path").should eql(@record.slug_with_path)
    end
    
    it "should remove the cached slug when the slug is deleted" do
      @record.slug
      @record.slug_with_path
      Rails.cache.read("Slug/User/#{@record.id}/slug").should eql(@record.slug)
      Rails.cache.read("Slug/User/#{@record.id}/slug_with_path").should eql(@record.slug_with_path)
      
      Slug.for(@record).first.destroy
      Rails.cache.read("Slug/User/#{@record.id}/slug").should be_nil
      Rails.cache.read("Slug/User/#{@record.id}/slug_with_path").should be_nil
    end
  end
end
