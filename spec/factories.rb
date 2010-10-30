Factory.define :slug do |f|
  f.sequence(:slug) { |n| "slug-#{n}" }
  f.active true
end

Factory.define :user do |f|
  f.first_name "Doctor"
  f.last_name "Spaceman"
end

Factory.define :abuser do |f|
  f.first_name "Doctor"
  f.last_name "Spaceman"
end
