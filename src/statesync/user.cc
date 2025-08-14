/*
    Mosh: the mobile shell
    Copyright 2012 Keith Winstein

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give
    permission to link the code of portions of this program with the
    OpenSSL library under certain conditions as described in each
    individual source file, and distribute linked combinations including
    the two.

    You must obey the GNU General Public License in all respects for all
    of the code used other than OpenSSL. If you modify file(s) with this
    exception, you may extend this exception to your version of the
    file(s), but you are not obligated to do so. If you do not wish to do
    so, delete this exception statement from your version. If you delete
    this exception statement from all source files in the program, then
    also delete it here.
*/

#include <cassert>
#include <typeinfo>

#include "src/serialization/mosh_serialization.h"
#include "src/statesync/user.h"
#include "src/util/fatal_assert.h"

using namespace Parser;
using namespace Network;

void UserStream::subtract( const UserStream* prefix )
{
  // if we are subtracting ourself from ourself, just clear the std::deque
  if ( this == prefix ) {
    actions.clear();
    return;
  }
  for ( std::deque<UserEvent>::const_iterator i = prefix->actions.begin(); i != prefix->actions.end(); i++ ) {
    assert( this != prefix );
    assert( !actions.empty() );
    assert( *i == actions.front() );
    actions.pop_front();
  }
}

std::string UserStream::diff_from( const UserStream& existing ) const
{
  std::deque<UserEvent>::const_iterator my_it = actions.begin();

  for ( std::deque<UserEvent>::const_iterator i = existing.actions.begin(); i != existing.actions.end(); i++ ) {
    assert( my_it != actions.end() );
    assert( *i == *my_it );
    my_it++;
  }

  Mosh::UserMessage msg;
  std::string pending_keys;

  while ( my_it != actions.end() ) {
    switch ( my_it->type ) {
      case UserByteType: {
        // Accumulate keystrokes to combine them efficiently
        pending_keys += my_it->userbyte.c;
      } break;
      case ResizeType: {
        // Flush any pending keystrokes before resize
        if ( !pending_keys.empty() ) {
          msg.addKeystroke( pending_keys );
          pending_keys.clear();
        }
        msg.addResize( my_it->resize.width, my_it->resize.height );
      } break;
      default:
        assert( !"unexpected event type" );
        break;
    }

    my_it++;
  }

  // Flush any remaining keystrokes
  if ( !pending_keys.empty() ) {
    msg.addKeystroke( pending_keys );
  }

  return msg.serialize();
}

void UserStream::apply_string( const std::string& diff )
{
  MoshUserMessage* msg = mosh_user_message_deserialize(
    reinterpret_cast<const uint8_t*>(diff.data()), 
    diff.size()
  );
  fatal_assert( msg != nullptr );

  size_t instruction_count = mosh_user_message_get_instruction_count( msg );
  
  for ( size_t i = 0; i < instruction_count; i++ ) {
    uint8_t inst_type = mosh_user_message_get_instruction_type( msg, i );
    
    if ( inst_type == MOSH_USER_INSTRUCTION_KEYSTROKE ) {
      const char* keys_data;
      size_t keys_len;
      
      if ( mosh_user_message_get_keystroke_keys( msg, i, &keys_data, &keys_len ) ) {
        for ( size_t loc = 0; loc < keys_len; loc++ ) {
          actions.push_back( UserEvent( UserByte( keys_data[loc] ) ) );
        }
      }
    } else if ( inst_type == MOSH_USER_INSTRUCTION_RESIZE ) {
      uint32_t width, height;
      
      if ( mosh_user_message_get_resize_dimensions( msg, i, &width, &height ) ) {
        actions.push_back( UserEvent( Resize( width, height ) ) );
      }
    }
  }

  mosh_user_message_destroy( msg );
}

const Parser::Action& UserStream::get_action( unsigned int i ) const
{
  switch ( actions[i].type ) {
    case UserByteType:
      return actions[i].userbyte;
    case ResizeType:
      return actions[i].resize;
    default:
      assert( !"unexpected action type" );
      static const Parser::Ignore nothing = Parser::Ignore();
      return nothing;
  }
}
