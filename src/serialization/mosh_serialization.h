#ifndef MOSH_SERIALIZATION_H
#define MOSH_SERIALIZATION_H

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

// Instruction type constants (must match Zig enums)
#define MOSH_USER_INSTRUCTION_KEYSTROKE 1
#define MOSH_USER_INSTRUCTION_RESIZE 2

#define MOSH_HOST_INSTRUCTION_HOST_BYTES 1
#define MOSH_HOST_INSTRUCTION_RESIZE 2
#define MOSH_HOST_INSTRUCTION_ECHO_ACK 3

extern "C" {
    struct MoshUserMessage;
    struct MoshHostMessage;
    struct MoshTransportInstruction;

    // User Message API
    MoshUserMessage* mosh_user_message_create();
    void mosh_user_message_destroy(MoshUserMessage* msg);
    bool mosh_user_message_add_keystroke(MoshUserMessage* msg, const char* keys, size_t len);
    bool mosh_user_message_add_resize(MoshUserMessage* msg, uint32_t width, uint32_t height);
    bool mosh_user_message_serialize(const MoshUserMessage* msg, uint8_t* buffer, size_t buffer_size, size_t* out_size);
    MoshUserMessage* mosh_user_message_deserialize(const uint8_t* buffer, size_t buffer_size);
    
    // User Message iteration API
    size_t mosh_user_message_get_instruction_count(const MoshUserMessage* msg);
    uint8_t mosh_user_message_get_instruction_type(const MoshUserMessage* msg, size_t index);
    bool mosh_user_message_get_keystroke_keys(const MoshUserMessage* msg, size_t index, const char** out_data, size_t* out_len);
    bool mosh_user_message_get_resize_dimensions(const MoshUserMessage* msg, size_t index, uint32_t* width, uint32_t* height);

    // Host Message API
    MoshHostMessage* mosh_host_message_create();
    void mosh_host_message_destroy(MoshHostMessage* msg);
    bool mosh_host_message_add_host_bytes(MoshHostMessage* msg, const char* bytes, size_t len);
    bool mosh_host_message_add_resize(MoshHostMessage* msg, uint32_t width, uint32_t height);
    bool mosh_host_message_add_echo_ack(MoshHostMessage* msg, uint64_t echo_ack_num);
    bool mosh_host_message_serialize(const MoshHostMessage* msg, uint8_t* buffer, size_t buffer_size, size_t* out_size);
    MoshHostMessage* mosh_host_message_deserialize(const uint8_t* buffer, size_t buffer_size);
    
    // Host Message iteration API
    size_t mosh_host_message_get_instruction_count(const MoshHostMessage* msg);
    uint8_t mosh_host_message_get_instruction_type(const MoshHostMessage* msg, size_t index);
    bool mosh_host_message_get_host_bytes(const MoshHostMessage* msg, size_t index, const char** out_data, size_t* out_len);
    bool mosh_host_message_get_resize_dimensions_host(const MoshHostMessage* msg, size_t index, uint32_t* width, uint32_t* height);
    bool mosh_host_message_get_echo_ack_num(const MoshHostMessage* msg, size_t index, uint64_t* echo_ack_num);

    // Transport Instruction API
    MoshTransportInstruction* mosh_transport_instruction_create();
    void mosh_transport_instruction_destroy(MoshTransportInstruction* inst);
    void mosh_transport_instruction_set_protocol_version(MoshTransportInstruction* inst, uint32_t version);
    void mosh_transport_instruction_set_old_num(MoshTransportInstruction* inst, uint64_t num);
    void mosh_transport_instruction_set_new_num(MoshTransportInstruction* inst, uint64_t num);
    void mosh_transport_instruction_set_ack_num(MoshTransportInstruction* inst, uint64_t num);
    void mosh_transport_instruction_set_throwaway_num(MoshTransportInstruction* inst, uint64_t num);
    bool mosh_transport_instruction_set_diff(MoshTransportInstruction* inst, const char* diff, size_t len);
    bool mosh_transport_instruction_set_chaff(MoshTransportInstruction* inst, const char* chaff, size_t len);
    bool mosh_transport_instruction_serialize(const MoshTransportInstruction* inst, uint8_t* buffer, size_t buffer_size, size_t* out_size);
    MoshTransportInstruction* mosh_transport_instruction_deserialize(const uint8_t* buffer, size_t buffer_size);
    
    // Transport Instruction accessor API
    bool mosh_transport_instruction_get_protocol_version(const MoshTransportInstruction* inst, uint32_t* out_value);
    bool mosh_transport_instruction_get_old_num(const MoshTransportInstruction* inst, uint64_t* out_value);
    bool mosh_transport_instruction_get_new_num(const MoshTransportInstruction* inst, uint64_t* out_value);
    bool mosh_transport_instruction_get_ack_num(const MoshTransportInstruction* inst, uint64_t* out_value);
    bool mosh_transport_instruction_get_throwaway_num(const MoshTransportInstruction* inst, uint64_t* out_value);
    bool mosh_transport_instruction_get_diff(const MoshTransportInstruction* inst, const char** out_data, size_t* out_len);
    bool mosh_transport_instruction_get_chaff(const MoshTransportInstruction* inst, const char** out_data, size_t* out_len);
}

namespace Mosh {
    class UserMessage {
    private:
        MoshUserMessage* handle;
    public:
        UserMessage() : handle(mosh_user_message_create()) {}
        ~UserMessage() { mosh_user_message_destroy(handle); }
        
        // Disable copy constructor and assignment
        UserMessage(const UserMessage&) = delete;
        UserMessage& operator=(const UserMessage&) = delete;
        
        // Enable move semantics
        UserMessage(UserMessage&& other) noexcept : handle(other.handle) {
            other.handle = nullptr;
        }
        UserMessage& operator=(UserMessage&& other) noexcept {
            if (this != &other) {
                mosh_user_message_destroy(handle);
                handle = other.handle;
                other.handle = nullptr;
            }
            return *this;
        }
        
        void addKeystroke(const std::string& keys) {
            mosh_user_message_add_keystroke(handle, keys.c_str(), keys.length());
        }
        
        void addResize(uint32_t width, uint32_t height) {
            mosh_user_message_add_resize(handle, width, height);
        }
        
        std::string serialize() const {
            std::vector<uint8_t> buffer(4096); // Reasonable max size
            size_t actual_size;
            if (mosh_user_message_serialize(handle, buffer.data(), buffer.size(), &actual_size)) {
                return std::string(reinterpret_cast<char*>(buffer.data()), actual_size);
            }
            return "";
        }
        
        static std::unique_ptr<UserMessage> deserialize(const std::string& data) {
            auto* handle = mosh_user_message_deserialize(
                reinterpret_cast<const uint8_t*>(data.data()), 
                data.size()
            );
            if (!handle) return nullptr;
            auto msg = std::make_unique<UserMessage>();
            mosh_user_message_destroy(msg->handle);
            msg->handle = handle;
            return msg;
        }
    };
    
    class HostMessage {
    private:
        MoshHostMessage* handle;
    public:
        HostMessage() : handle(mosh_host_message_create()) {}
        ~HostMessage() { mosh_host_message_destroy(handle); }
        
        // Disable copy constructor and assignment
        HostMessage(const HostMessage&) = delete;
        HostMessage& operator=(const HostMessage&) = delete;
        
        // Enable move semantics
        HostMessage(HostMessage&& other) noexcept : handle(other.handle) {
            other.handle = nullptr;
        }
        HostMessage& operator=(HostMessage&& other) noexcept {
            if (this != &other) {
                mosh_host_message_destroy(handle);
                handle = other.handle;
                other.handle = nullptr;
            }
            return *this;
        }
        
        void addHostBytes(const std::string& bytes) {
            mosh_host_message_add_host_bytes(handle, bytes.c_str(), bytes.length());
        }
        
        void addResize(uint32_t width, uint32_t height) {
            mosh_host_message_add_resize(handle, width, height);
        }
        
        void addEchoAck(uint64_t echo_ack_num) {
            mosh_host_message_add_echo_ack(handle, echo_ack_num);
        }
        
        std::string serialize() const {
            std::vector<uint8_t> buffer(65536); // Larger buffer for host messages
            size_t actual_size;
            if (mosh_host_message_serialize(handle, buffer.data(), buffer.size(), &actual_size)) {
                return std::string(reinterpret_cast<char*>(buffer.data()), actual_size);
            }
            return "";
        }
        
        static std::unique_ptr<HostMessage> deserialize(const std::string& data) {
            auto* handle = mosh_host_message_deserialize(
                reinterpret_cast<const uint8_t*>(data.data()), 
                data.size()
            );
            if (!handle) return nullptr;
            auto msg = std::make_unique<HostMessage>();
            mosh_host_message_destroy(msg->handle);
            msg->handle = handle;
            return msg;
        }
    };
    
    class TransportInstruction {
    private:
        MoshTransportInstruction* handle;
    public:
        TransportInstruction() : handle(mosh_transport_instruction_create()) {}
        ~TransportInstruction() { mosh_transport_instruction_destroy(handle); }
        
        // Disable copy constructor and assignment
        TransportInstruction(const TransportInstruction&) = delete;
        TransportInstruction& operator=(const TransportInstruction&) = delete;
        
        // Enable move semantics
        TransportInstruction(TransportInstruction&& other) noexcept : handle(other.handle) {
            other.handle = nullptr;
        }
        TransportInstruction& operator=(TransportInstruction&& other) noexcept {
            if (this != &other) {
                mosh_transport_instruction_destroy(handle);
                handle = other.handle;
                other.handle = nullptr;
            }
            return *this;
        }
        
        void setProtocolVersion(uint32_t version) {
            mosh_transport_instruction_set_protocol_version(handle, version);
        }
        
        void setOldNum(uint64_t num) {
            mosh_transport_instruction_set_old_num(handle, num);
        }
        
        void setNewNum(uint64_t num) {
            mosh_transport_instruction_set_new_num(handle, num);
        }
        
        void setAckNum(uint64_t num) {
            mosh_transport_instruction_set_ack_num(handle, num);
        }
        
        void setThrowawayNum(uint64_t num) {
            mosh_transport_instruction_set_throwaway_num(handle, num);
        }
        
        void setDiff(const std::string& diff) {
            mosh_transport_instruction_set_diff(handle, diff.c_str(), diff.length());
        }
        
        void setChaff(const std::string& chaff) {
            mosh_transport_instruction_set_chaff(handle, chaff.c_str(), chaff.length());
        }
        
        std::string serialize() const {
            std::vector<uint8_t> buffer(65536); // Large buffer for transport messages
            size_t actual_size;
            if (mosh_transport_instruction_serialize(handle, buffer.data(), buffer.size(), &actual_size)) {
                return std::string(reinterpret_cast<char*>(buffer.data()), actual_size);
            }
            return "";
        }
        
        static std::unique_ptr<TransportInstruction> deserialize(const std::string& data) {
            auto* handle = mosh_transport_instruction_deserialize(
                reinterpret_cast<const uint8_t*>(data.data()), 
                data.size()
            );
            if (!handle) return nullptr;
            auto inst = std::make_unique<TransportInstruction>();
            mosh_transport_instruction_destroy(inst->handle);
            inst->handle = handle;
            return inst;
        }
    };
}

#endif // MOSH_SERIALIZATION_H