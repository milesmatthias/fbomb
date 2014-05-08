module FBomb
  class Flowdawk
    include Flowdock

    module SearchExtension
      def search(term)
        room = self
        term = CGI.escape(term.to_s)
        return_to_room_id = CGI.escape(room.id.to_s)
        messages = connection.get("/search?term=#{ term }&return_to_room_id=#{ return_to_room_id }")
        if messages and messages.is_a?(Hash)
          messages = messages['messages']
        end
        messages.each do |message|
          message['created_at_time'] = Time.parse(message['created_at'])
        end
        messages.replace(messages.sort_by{|message| message['created_at_time']}) 
        messages
      end
    end

    module UserExtension
      Cached = {}

      def user(id)
        user = Cached[id]
        return user if user

        if id
          user = users.detect{|u| u[:id] == id}
          unless user
            user_data = connection.get("/users/#{ id }.json")
            user = user_data && user_data['user']
          end
          user['created_at'] = Time.parse(user['created_at'])
          Cached[id] = user
        end
      end
    end

    module StreamExtension
      def stream
        @stream ||= (
          room = self
          Twitter::JSONStream.connect(
            :path => "/#{ domain }/#{ room.name }",
            :host => 'stream.flowdock.com',
            :auth => "#{ connection.token }:x"
          )
        )
      end

      def streaming(&block)
        steam.instance_eval(&block)
      end
    end

    module UrlExtension
      attr_accessor :flowawk

      def url
        File.join(flow.url, "flow/#{ id }")
      end
    end

    def Flowdawk.new(*args, &block)
      allocate.tap do |instance|
        instance.send(:initialize, *args, &block)
      end
    end

    def flow_for(name)
      name = name.to_s
      flow = flows.detect{|_| _.name == name}
      flow.extend(SearchExtension)
      flow.extend(UserExtension)
      flow.extend(StreamExtension)
      flow.extend(UrlExtension)
      flow.flowdawk = self
      flow
    end

    attr_accessor :token

    def url
      if token
        "#{ scheme }://#{ token }:X@#{ host }"
      else
        "#{ scheme }://#{ host }"
      end
    end

    def host
      connection.raw_connection.host
    end

    def scheme
      connection.raw_connection.scheme
    end
  end
end
