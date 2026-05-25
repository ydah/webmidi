# frozen_string_literal: true

require "socket"
require "securerandom"

module Webmidi
  module Network
    module AppleMIDI
      module_function

      def server(port: 5004, name: "Webmidi")
        Session.new(port: port, name: name, mode: :server)
      end

      def connect(host, port: 5004, name: "Webmidi Client")
        session = Session.new(port: 0, name: name, mode: :client)
        session.connect_to(host, port)
        session
      end

      class Session
        attr_reader :name, :control_port, :data_port, :ssrc

        def initialize(port:, name:, mode: :server)
          @requested_control_port = port
          @requested_data_port = port.zero? ? 0 : port + 1
          @name = name
          @mode = mode
          @ssrc = SecureRandom.random_number(0xFFFFFFFF)
          @rtp = RTP::Session.new(port: @requested_data_port, name: name, mode: mode, ssrc: @ssrc)
          @pending_tokens = {}
          @control_peers = []
          @mutex = Mutex.new
          @running = false
          @control_socket = nil
          @control_thread = nil
          @data_subscription = nil
        end

        def start
          return self if @running

          @rtp.start
          @data_port = @rtp.port
          @data_subscription = @rtp.on_control_packet { |packet, peer| handle_control_packet(packet, peer, :data) }
          @control_socket = UDPSocket.new
          @control_socket.bind("0.0.0.0", @requested_control_port)
          @control_port = @control_socket.addr[1]
          @running = true
          @control_thread = Thread.new { control_loop }
          self
        end

        def stop
          @running = false
          @control_socket&.close
          @control_thread&.join(1)
          @data_subscription&.unsubscribe
          @rtp.stop
          self
        end

        alias_method :close, :stop

        def connect_to(host, port, data_port: port + 1)
          start unless @running

          token = SecureRandom.random_number(0xFFFF_FFFF)
          peer = {host: host, control_port: port, data_port: data_port}
          @mutex.synchronize { @pending_tokens[token] = peer }
          send_control(RTP::ControlPacket.invitation(token: token, ssrc: @ssrc, name: @name), host, port)
          self
        end

        def send(message)
          @rtp.send(message)
        end

        def on_message(&block)
          @rtp.on_message(&block)
        end

        def on_error(&block)
          @rtp.on_error(&block)
        end

        def peers
          @rtp.peers
        end

        private

        def control_loop
          while @running
            begin
              data, address = @control_socket.recvfrom_nonblock(1024)
              packet = RTP::ControlPacket.parse(data)
              handle_control_packet(packet, {host: address[3], port: address[1]}, :control) if packet
            rescue IO::WaitReadable
              break unless @running

              begin
                IO.select([@control_socket], nil, nil, 0.1)
              rescue IOError, SystemCallError
                break
              end
            rescue IOError, SystemCallError
              break
            rescue => e
              notify_error(e, data)
            end
          end
        end

        def handle_control_packet(packet, peer, channel)
          case packet.command
          when :invitation
            accept_invitation(packet, peer, channel)
          when :accepted
            accept_response(packet, peer, channel)
          when :rejected
            @mutex.synchronize { @pending_tokens.delete(packet.token) }
          when :synchronization
            reply_to_synchronization(packet, peer, channel)
          when :end_session
            @rtp.remove_peer(peer[:host], peer[:port])
          end
        end

        def accept_invitation(packet, peer, channel)
          response = RTP::ControlPacket.accepted(token: packet.token, ssrc: @ssrc, name: @name)
          send_packet(response, peer[:host], peer[:port], channel)

          if channel == :data
            @rtp.add_peer(peer[:host], peer[:port])
          else
            @mutex.synchronize { @control_peers << peer unless @control_peers.include?(peer) }
          end
        end

        def accept_response(packet, peer, channel)
          pending = @mutex.synchronize { @pending_tokens[packet.token] }
          return unless pending

          if channel == :control
            send_data_invitation(packet.token, pending[:host], pending[:data_port])
          else
            @rtp.add_peer(peer[:host], peer[:port])
            @mutex.synchronize { @pending_tokens.delete(packet.token) }
          end
        end

        def send_data_invitation(token, host, port)
          invitation = RTP::ControlPacket.invitation(token: token, ssrc: @ssrc, name: @name)
          @rtp.send_control_packet(invitation, host, port)
        end

        def reply_to_synchronization(packet, peer, channel)
          return if packet.count >= 3

          timestamps = packet.timestamps.dup
          timestamps[packet.count] = RTP::ControlPacket.timestamp
          response = RTP::ControlPacket.synchronization(
            ssrc: @ssrc,
            count: packet.count + 1,
            timestamps: timestamps
          )
          send_packet(response, peer[:host], peer[:port], channel)
        end

        def send_packet(packet, host, port, channel)
          if channel == :data
            @rtp.send_control_packet(packet, host, port)
          else
            send_control(packet, host, port)
          end
        end

        def send_control(packet, host, port)
          @control_socket&.send(packet.to_bytes, 0, host, port)
        end

        def notify_error(error, data = nil)
          @rtp.send(:notify_error, error, data)
        end
      end
    end
  end
end
