#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'PostureDetector.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the PostureLiveActivityExtension target
extension_target = project.targets.find { |t| t.name == 'PostureLiveActivityExtension' }

unless extension_target
  puts "Error: PostureLiveActivityExtension target not found"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end

# Set entitlements path in build settings
extension_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'PostureLiveActivity/PostureLiveActivity.entitlements'
  puts "Set CODE_SIGN_ENTITLEMENTS for #{config.name} configuration"
end

project.save
puts "✅ Project updated successfully!"
