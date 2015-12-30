require 'omniauth/strategies/oauth2'
require 'base64'
require 'openssl'
require 'rack/utils'

module OmniAuth
  module Strategies
    class Playapi < OmniAuth::Strategies::OAuth2
      class NoAuthorizationCodeError < StandardError; end

      args [:client_id, :ssl_cert, :ssl_key, :client_options]

      DEFAULT_SCOPE = 'oauth/*'
      
      option :client_options, {
        :site => 'https://oauth.play.pl',
        :authorize_url => "https://oauth.play.pl/oauth/authorize",
        :token_url => 'https://oapi.play.pl/oauth2/oauth/token',      
        :info_url => 'https://oapi.play.pl/oauth2/resource/profile',
        :authorize_params => {}    
      }
                                   
      option :authorize_options, [:response_type, :scope, :state, :redirect_uri, :display, :hint, :approval_prompt]
      option :auth_token_params, {
       :mode => :query, 
        :param_name => "access_token"
      }

      #custom as PlayAPI redirect_url cannot contain query_string
      def callback_url
        full_host + script_name + callback_path
      end

      def client
       set_ssl_params                            
       log :debug, "client #{options.to_json} "
        ::OAuth2::Client.new(options.client_id, options.client_id, deep_symbolize(options.client_options))
      end

      def authorize_params
        super.tap do |params|
          options[:authorize_options].each do |k|
            params[k] = request.params[k.to_s] unless [nil, ''].include?(request.params[k.to_s])                      
            params[k] = options.client_options[:authorize_params][k.to_s] unless [nil, ''].include? options.client_options[:authorize_params][k.to_s]
          end

          raw_scope = params[:scope] || DEFAULT_SCOPE
          scope_list = raw_scope.split(" ").map {|item| item.split(",")}.flatten
          params[:scope] = scope_list.join(" ")          

          session['omniauth.state'] = params[:state] if params['state']
          log :debug, "authorize_params #{params.to_json} "          
        end
      end

      uid { raw_info['msisdn'] }

      credentials do
        hash = {"token" => access_token.token}
        hash.merge!("refresh_token" => access_token.refresh_token) if access_token.expires? && access_token.refresh_token
        hash.merge!("expires_at" => access_token.expires_at) if access_token.expires?
        hash.merge!("expires" => access_token.expires?)
        raw_scope=access_token.params["scope"] unless  access_token.params.blank?
        unless raw_scope.blank?
          scope_list=raw_scope.split(" ")
          hash.merge!("scope" => scope_list)
        end     
        hash
      end
      
      info do
        prune!({
          'nickname' => raw_info['msisdn'],
          'name' => raw_info['msisdn'],          
          'login_type' => raw_info['loginType'],
          'email' => raw_info['loginType'] == 'SSO' && raw_info['ssoProfile']['login'] || '',
        })
      end

      extra do
        hash = {}
        hash['raw_info'] = raw_info unless skip_info?
        prune! hash
      end

      def raw_info
        if @raw_info.blank?                                            
          log :debug, "raw_info GET: #{options.client_options.info_url}"
          @raw_info ||=  access_token.get( options.client_options.info_url ).parsed
        end  
        log :debug, "raw_info #{@raw_info}"
        return @raw_info
      end
      
      protected
      def build_access_token                       
        #access_token=super        
        verifier = request.params["code"]
        callback = full_host + script_name + callback_path        
        log :debug, "build_access_token for #{callback} code=#{verifier} "             
        access_token=client.auth_code.get_token(verifier, {:redirect_uri => callback}, deep_symbolize(options.auth_token_params))
        log :info, "access_token granted: #{access_token.token}"        
        return access_token                                
      end
      
      private

      def set_ssl_params
        if @ssl_opts.blank? and options.client_options[:ssl].blank?    
          if File.exist?("#{options.ssl_cert}") and File.exist?("#{options.ssl_key}")
            options.client_options[:ssl]={ 
              :client_cert =>  OpenSSL::PKey::RSA.new(    File.read(  "#{options.ssl_cert}"  ) ),
              :client_key =>  OpenSSL::PKey::RSA.new(     File.read(  "#{options.ssl_key}"  ) ),
              :verify_mode => OpenSSL::SSL::VERIFY_PEER          
            }            
            log :debug, "set_ssl_params: #{options.client_options[:ssl]}"
          else          
            @ssl_opts="NoSSL"
            log :debug, "set_ssl_params: SSL disabled"
          end
        end        
      end

      
      def prune!(hash)
        hash.delete_if do |_, value|
          prune!(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

    end
  end
end