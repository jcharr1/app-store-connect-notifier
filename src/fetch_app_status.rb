# frozen_string_literal: true

# Needed to load gems from Gemfile
require "rubygems"
require "bundler/setup"

require "spaceship"
require "json"

# Constants
def bundle_ids
  ENV["BUNDLE_IDENTIFIERS"]
end

def itc_username
  ENV["ITC_USERNAME"]
end

def itc_password
  ENV["ITC_PASSWORD"]
end

def spaceship_connect_api_key_id
  ENV["SPACESHIP_CONNECT_API_KEY_ID"]
end

def spaceship_connect_api_issuer_id
  ENV["SPACESHIP_CONNECT_API_ISSUER_ID"]
end

def spaceship_connect_api_key
  ENV["SPACESHIP_CONNECT_API_KEY"]
end

def uses_app_store_connect_auth_token
  !spaceship_connect_api_key_id.nil? && !spaceship_connect_api_issuer_id.nil? && !spaceship_connect_api_key.nil?
end

def uses_app_store_connect_auth_credentials
  !uses_app_store_connect_auth_token && !itc_username.nil?
end

def itc_team_id_array
  # Split team_id
  ENV["ITC_TEAM_IDS"].to_s.split(",")
end

def number_of_builds
  (ENV["NUMBER_OF_BUILDS"] || 1).to_i
end

unless uses_app_store_connect_auth_token || uses_app_store_connect_auth_credentials
  puts "Couldn't find valid authentication token or credentials."
  exit
end

def get_version_info(app)
  latest_version_info = app.get_latest_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
  # FIXME: Analyze how to read the store icon. See https://github.com/fastlane/fastlane/issues/17370 for more info.
  if uses_app_store_connect_auth_credentials
    icon_url = latest_version_info.store_icon["templateUrl"]
    icon_url["{w}"] = "340"
    icon_url["{h}"] = "340"
    icon_url["{f}"] = "png"
  end
  {
    "name" => app.name,
    "version" => latest_version_info.version_string,
    "status" => latest_version_info.app_store_state,
    "appId" => app.id,
    "iconUrl" => icon_url,
  }
end

def get_build_info(app)
  builds = app.get_builds(includes: "preReleaseVersion,betaAppReviewSubmission,buildBetaDetail").sort_by(&:uploaded_date).reverse[0, number_of_builds]

  # Attempt to map build IDs to their corresponding pre-release (short) version.
  short_version_by_build_id = {}
  begin
    prv_list = app.get_pre_release_versions(platform: Spaceship::ConnectAPI::Platform::IOS)
    prv_list.each do |prv|
      sv = nil
      begin
        sv = prv.version
      rescue StandardError
        sv = nil
      end
      # Try to retrieve builds associated with this pre-release version
      related_builds = []
      begin
        related_builds = prv.get_builds
      rescue StandardError
        begin
          related_builds = prv.builds
        rescue StandardError
          related_builds = []
        end
      end
      related_builds.each do |b|
        begin
          short_version_by_build_id[b.id] = sv
        rescue StandardError
        end
      end
    end
  rescue StandardError
    # If any of the above fails, we'll gracefully return nil short versions
  end

  builds.map do |build|
    beta_review_state = nil
    begin
      if build.respond_to?(:beta_app_review_submission) && build.beta_app_review_submission
        beta_review_state = build.beta_app_review_submission.beta_review_state
      elsif build.respond_to?(:beta_review_state)
        beta_review_state = build.beta_review_state
      end
    rescue StandardError
      beta_review_state = nil
    end

    external_build_state = nil
    begin
      if build.respond_to?(:build_beta_detail) && build.build_beta_detail
        external_build_state = build.build_beta_detail.external_build_state
      end
    rescue StandardError
      external_build_state = nil
    end

    short_version = nil
    begin
      short_version = build.app_version
    rescue StandardError
      short_version = short_version_by_build_id[build.id]
    end

    {
      id: build.id,
      version: build.version, # build number
      short_version: short_version, # app version associated with the build
      uploaded_data: build.uploaded_date,
      status: build.processing_state, # processing state (VALID/INVALID/PROCESSING)
      beta_review_state: beta_review_state, # e.g., WAITING_FOR_REVIEW/IN_REVIEW/APPROVED/REJECTED
      external_build_state: external_build_state, # e.g., READY_FOR_TESTING, BETA_EXPIRED, etc.
    }
  end
end

def get_app_version_from(bundle_ids)
  apps = []
  if bundle_ids
    bundle_ids.split(",").each do |id|
      apps.push(Spaceship::ConnectAPI::App.find(id))
    end
  else
    apps = Spaceship::ConnectAPI::App.all
  end
  apps.map do |app|
    info = get_version_info(app)
    info["builds"] = get_build_info(app)
    info
  end
end

if uses_app_store_connect_auth_token
  Spaceship::ConnectAPI.auth(key_id: spaceship_connect_api_key_id, issuer_id: spaceship_connect_api_issuer_id, key: spaceship_connect_api_key)
else
  Spaceship::ConnectAPI.login(itc_username, itc_password)
end

# All json data
versions = []

# Add for the team_ids
# Test if itc_team doesnt exists
if itc_team_id_array.length.zero?
  versions += get_app_version_from(bundle_ids)
else
  itc_team_id_array.each do |itc_team_id|
    Spaceship::ConnectAPI.select_team(tunes_team_id: itc_team_id) if itc_team_id
    versions += get_app_version_from(bundle_ids)
  end
end

puts JSON.dump versions
