#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'PostureDetector.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the PostureLiveActivityExtension target
extension_target = project.targets.find { |t| t.name == 'PostureLiveActivityExtension' }

unless extension_target
  puts "Error: PostureLiveActivityExtension target not found"
  exit 1
end

# Find or create the PostureLiveActivity group
live_activity_group = project.main_group.groups.find { |g| g.path == 'PostureLiveActivity' }

if live_activity_group
  # Add entitlements file reference
  entitlements_file = live_activity_group.new_file('PostureLiveActivity.entitlements')
  
  # Update build settings to point to the entitlements file
  extension_target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'PostureLiveActivity/PostureLiveActivity.entitlements'
  end
  
  puts "✅ Added PostureLiveActivity.entitlements to PostureLiveActivityExtension target"
else
  puts "Warning: PostureLiveActivity group not found"
end

project.save
puts "Project updated successfully!"
