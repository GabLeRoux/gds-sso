module GDS
  module SSO
    module ControllerMethods
      class PermissionDeniedException < StandardError
      end

      def self.included(base)
        base.rescue_from PermissionDeniedException do |e|
          render "authorisations/unauthorised", layout: "unauthorised", status: :forbidden, locals: { message: e.message }
        end
        base.helper_method :user_signed_in?
        base.helper_method :current_user
      end


      def authorise_user!(permissions)
        # Ensure that we're authenticated (and by extension that current_user is set).
        # Otherwise current_user might be nil, and we'd error out
        authenticate_user!

        case permissions
        when String
          unless current_user.has_permission?(permissions)
            raise PermissionDeniedException, "Sorry, you don't seem to have the #{permissions} permission for this app."
          end
        when Hash
          raise ArgumentError, "Must be either `any_of` or `all_of`" unless permissions.keys.size == 1

          if permissions[:any_of]
            authorise_user_with_at_least_one_of_permissions!(permissions[:any_of])
          elsif permissions[:all_of]
            authorise_user_with_all_permissions!(permissions[:all_of])
          else
            raise ArgumentError, "Must be either `any_of` or `all_of`"
          end
        end
      end

      def require_signin_permission!
        ActiveSupport::Deprecation.warn("require_signin_permission! is deprecated and will be removed in a future version.  The signon application checks for signin permission during oauth and it is no longer optional.", caller)
        authorise_user!('signin')
      rescue PermissionDeniedException
        render "authorisations/cant_signin", layout: "unauthorised", status: :forbidden
      end

      def authenticate_user!
        warden.authenticate!
      end

      def user_remotely_signed_out?
        warden && warden.authenticated? && warden.user.remotely_signed_out?
      end

      def user_signed_in?
        warden && warden.authenticated? && ! warden.user.remotely_signed_out?
      end

      def current_user
        warden.user if user_signed_in?
      end

      def logout
        warden.logout
      end

      def warden
        request.env['warden']
      end

      private

      def authorise_user_with_at_least_one_of_permissions!(permissions)
        if permissions.none? { |permission| current_user.has_permission?(permission) }
          raise PermissionDeniedException,
            "Sorry, you don't seem to have any of the permissions: #{permissions.to_sentence} for this app."
        end
      end

      def authorise_user_with_all_permissions!(permissions)
        unless permissions.all? { |permission| current_user.has_permission?(permission) }
          raise PermissionDeniedException,
            "Sorry, you don't seem to have all of the permissions: #{permissions.to_sentence} for this app."
        end
      end
    end
  end
end
