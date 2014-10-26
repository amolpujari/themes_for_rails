# encoding: utf-8
require "action_controller/metal"

module ThemesForRails
  class AssetsController < ActionController::Base

    def stylesheets
      handle_asset("stylesheets")
    end

    def javascripts
      handle_asset("javascripts")
    end

    def images
      handle_asset("images")
    end

    def fonts
      handle_asset("fonts")
    end

  private
    
    def handle_asset(prefix)
      asset, theme = params[:asset], params[:theme]
      Rails.logger.debug "FRANKIE"
      Rails.logger.debug params
      if ThemesForRails.config.database_enabled and (record = find_themed_asset_in_database(asset, theme, prefix).first)
        Rails.logger.debug "SENDING CONTENT"
        mime_type = mime_type_for(request)
        response.headers['ETag'] = %("#{Digest::MD5.hexdigest(ActiveSupport::Cache.expand_cache_key(record.updated_at.to_s + record.path))}")
        response.headers['Cache-Control'] = "public, max-age=2592000"
        send_data record.content, :type => mime_type, :disposition => "inline"
      else
        Rails.logger.debug "SENDING FILE"
        find_themed_asset(asset, theme, prefix) do |path, mime_type|
           Rails.logger.debug "FILE #{path}"
          response.headers['ETag'] = %("#{Digest::MD5.hexdigest(ActiveSupport::Cache.expand_cache_key(File.mtime(path).to_s + path))}")
          response.headers['Cache-Control'] = "public, max-age=2592000"
          send_file path, :type => mime_type, :disposition => "inline"
        end
      end
    end

    def find_themed_asset_in_database(asset_name, asset_theme, asset_type, &block)
      conditions = {
        :path => "#{asset_type}/#{asset_name}",
        :theme_id => asset_theme.id
      }
      CustomTemplate.where(conditions).map do |record|
        record
      end
    end
    
    def find_themed_asset(asset_name, asset_theme, asset_type, &block)
      path = asset_path(asset_name, asset_theme, asset_type)
       Rails.logger.debug "ASSET PATH #{path}"
      default_path = default_asset_path(asset_name, asset_theme, asset_type)
      if File.exists?(path)
        yield path, mime_type_for(request)
      elsif File.exists?(default_path)
        yield default_path, mime_type_for(request)
      elsif File.extname(path).blank?
        asset_name = "#{asset_name}.#{extension_from(request.path_info)}"
         Rails.logger.debug "ASSET NAME #{path}"
        return find_themed_asset(asset_name, asset_theme, asset_type, &block) 
      else
        render_not_found
      end
    end

    def asset_path(asset_name, asset_theme, asset_type)
      File.join(theme_asset_path_for(asset_theme), asset_type, asset_name)
    end

    def default_asset_path(asset_name, asset_theme, asset_type)
      File.join(default_theme_asset_path, asset_type, asset_name)
    end

    def render_not_found
      render :text => 'Not found', :status => 404
    end
      
    def mime_type_for(request)
      existing_mime_type = mime_type_from_uri(request.path_info)
      unless existing_mime_type.nil? 
        existing_mime_type.to_s
      else
        "image/#{extension_from(request.path_info)}"
      end
    end
    
    def mime_type_from_uri(path)
      extension = extension_from(path)
      Mime::Type.lookup_by_extension(extension)
    end
    
    def extension_from(path)
      File.extname(path).to_s[1..-1]
    end
  end
end
