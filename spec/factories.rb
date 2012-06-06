FactoryGirl.define do
  factory :slug do
    sequence(:slug) { |n| "slug-#{n}" }
    active true
  end

  factory :user do
    first_name "Doctor"
    last_name "Spaceman"
  end

  factory :abuser do
    first_name "Doctor"
    last_name "Spaceman"
  end
end
