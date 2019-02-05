require 'spec_helper'

describe Slug do
  before :each do
    @record = FactoryBot.create(:user)
    Slug.delete_all
  end

  context "[validation]" do
    it "should not allow an active slug to be created if one already exists" do
      FactoryBot.create(:slug, sluggable: @record)
      slug = FactoryBot.build(:slug, sluggable: @record)
      expect(slug).not_to be_valid
      expect(slug.errors[:active]).not_to be_empty
    end

    it "should not allow a slug to be made active if one already exists" do
      FactoryBot.create(:slug, sluggable: @record)
      slug = FactoryBot.create(:slug, sluggable: @record, active: false)
      slug.active = true
      expect(slug).not_to be_valid
      expect(slug.errors[:active]).not_to be_empty
    end

    it "should allow an active slug to be created if none exists" do
      slug = FactoryBot.build(:slug, sluggable: @record)
      expect(slug).to be_valid
    end

    it "should allow a slug to be made active if none exists" do
      slug = FactoryBot.create(:slug, sluggable: @record, active: false)
      slug.active = true
      expect(slug).to be_valid
    end

    it "should allow an inactive slug to be modified if the active field is not changing" do
      FactoryBot.create(:slug, sluggable: @record)
      slug = FactoryBot.create(:slug, sluggable: @record, active: false)
      slug.scope = 'test'
      expect(slug).to be_valid
    end
  end

  describe "#activate!" do
    it "should mark the slug as active" do
      slug = FactoryBot.create(:slug, sluggable: FactoryBot.create(:user), active: false)
      slug.activate!
      expect(slug).to be_active
    end

    it "should deactivate all the record's other slugs" do
      record = FactoryBot.create(:user)
      s1 = Slug.for(record).first
      s2 = FactoryBot.create(:slug, sluggable: record, active: false)
      s3 = FactoryBot.create(:slug, sluggable: record, active: false)

      slug = FactoryBot.create(:slug, sluggable: record, active: false)
      slug.activate!

      expect(s1.reload).not_to be_active
      expect(s2.reload).not_to be_active
      expect(s3.reload).not_to be_active
    end
  end
  
  context "[caching]" do
    before :each do
      FactoryBot.create(:slug, sluggable: @record)
    end
    
    it "should write the slug to the cache" do
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug")).to be_nil
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug_with_path")).to be_nil
      
      @record.slug
      @record.slug_with_path
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug")).to eql(@record.slug)
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug_with_path")).to eql(@record.slug_with_path)
    end
    
    it "should remove the cached slug when the slug is changed" do
      slug = FactoryBot.create(:slug, sluggable: @record, active: false)
      slug.activate!
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug")).to be_nil
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug_with_path")).to be_nil
      
      @record.slug
      @record.slug_with_path
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug")).to eql(@record.slug)
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug_with_path")).to eql(@record.slug_with_path)
    end
    
    it "should remove the cached slug when the slug is deleted" do
      @record.slug
      @record.slug_with_path
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug")).to eql(@record.slug)
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug_with_path")).to eql(@record.slug_with_path)
      
      Slug.for(@record).first.destroy
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug")).to be_nil
      expect(Rails.cache.read("Slug/User/#{@record.id}/slug_with_path")).to be_nil
    end
  end
end
