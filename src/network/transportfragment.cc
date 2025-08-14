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
#include <cstring>

#include "compressor.h"
#include "src/crypto/byteorder.h"
#include "src/serialization/mosh_serialization.h"
#include "src/util/fatal_assert.h"
#include "transportfragment.h"

using namespace Network;

static std::string network_order_string( uint16_t host_order )
{
  uint16_t net_int = htobe16( host_order );
  return std::string( (char*)&net_int, sizeof( net_int ) );
}

static std::string network_order_string( uint64_t host_order )
{
  uint64_t net_int = htobe64( host_order );
  return std::string( (char*)&net_int, sizeof( net_int ) );
}

std::string Fragment::tostring( void )
{
  assert( initialized );

  std::string ret;

  ret += network_order_string( id );

  fatal_assert(
    !( fragment_num & 0x8000 ) ); /* effective limit on size of a terminal screen change or buffered user input */
  uint16_t combined_fragment_num = ( final << 15 ) | fragment_num;
  ret += network_order_string( combined_fragment_num );

  assert( ret.size() == frag_header_len );

  ret += contents;

  return ret;
}

Fragment::Fragment( const std::string& x )
  : id( -1 ), fragment_num( -1 ), final( false ), initialized( true ), contents()
{
  fatal_assert( x.size() >= frag_header_len );
  contents = std::string( x.begin() + frag_header_len, x.end() );

  uint64_t data64;
  uint16_t* data16 = (uint16_t*)x.data();
  memcpy( &data64, x.data(), sizeof( data64 ) );
  id = be64toh( data64 );
  fragment_num = be16toh( data16[4] );
  final = ( fragment_num & 0x8000 ) >> 15;
  fragment_num &= 0x7FFF;
}

bool FragmentAssembly::add_fragment( Fragment& frag )
{
  /* see if this is a totally new packet */
  if ( current_id != frag.id ) {
    fragments.clear();
    fragments.resize( frag.fragment_num + 1 );
    fragments.at( frag.fragment_num ) = frag;
    fragments_arrived = 1;
    fragments_total = -1; /* unknown */
    current_id = frag.id;
  } else { /* not a new packet */
    /* see if we already have this fragment */
    if ( ( fragments.size() > frag.fragment_num ) && ( fragments.at( frag.fragment_num ).initialized ) ) {
      /* make sure new version is same as what we already have */
      assert( fragments.at( frag.fragment_num ) == frag );
    } else {
      if ( (int)fragments.size() < frag.fragment_num + 1 ) {
        fragments.resize( frag.fragment_num + 1 );
      }
      fragments.at( frag.fragment_num ) = frag;
      fragments_arrived++;
    }
  }

  if ( frag.final ) {
    fragments_total = frag.fragment_num + 1;
    assert( (int)fragments.size() <= fragments_total );
    fragments.resize( fragments_total );
  }

  if ( fragments_total != -1 ) {
    assert( fragments_arrived <= fragments_total );
  }

  /* see if we're done */
  return fragments_arrived == fragments_total;
}

MoshTransportInstruction* FragmentAssembly::get_assembly( void )
{
  assert( fragments_arrived == fragments_total );

  std::string encoded;

  for ( int i = 0; i < fragments_total; i++ ) {
    assert( fragments.at( i ).initialized );
    encoded += fragments.at( i ).contents;
  }

  std::string uncompressed = get_compressor().uncompress_str( encoded );
  MoshTransportInstruction* ret = mosh_transport_instruction_deserialize(
    reinterpret_cast<const uint8_t*>(uncompressed.data()),
    uncompressed.size()
  );
  fatal_assert( ret != nullptr );

  fragments.clear();
  fragments_arrived = 0;
  fragments_total = -1;

  return ret;
}

bool Fragment::operator==( const Fragment& x ) const
{
  return ( id == x.id ) && ( fragment_num == x.fragment_num ) && ( final == x.final )
         && ( initialized == x.initialized ) && ( contents == x.contents );
}

std::vector<Fragment> Fragmenter::make_fragments( const MoshTransportInstruction* inst, size_t MTU )
{
  MTU -= Fragment::frag_header_len;
  
  // Check if this is a new instruction by comparing fields
  bool is_new_instruction = false;
  
  uint64_t inst_old_num = 0, inst_new_num = 0, inst_ack_num = 0, inst_throwaway_num = 0;
  uint64_t last_old_num = 0, last_new_num = 0, last_ack_num = 0, last_throwaway_num = 0;
  uint32_t inst_protocol_version = 0, last_protocol_version = 0;
  
  mosh_transport_instruction_get_old_num( inst, &inst_old_num );
  mosh_transport_instruction_get_new_num( inst, &inst_new_num );
  mosh_transport_instruction_get_ack_num( inst, &inst_ack_num );
  mosh_transport_instruction_get_throwaway_num( inst, &inst_throwaway_num );
  mosh_transport_instruction_get_protocol_version( inst, &inst_protocol_version );
  
  mosh_transport_instruction_get_old_num( last_instruction, &last_old_num );
  mosh_transport_instruction_get_new_num( last_instruction, &last_new_num );
  mosh_transport_instruction_get_ack_num( last_instruction, &last_ack_num );
  mosh_transport_instruction_get_throwaway_num( last_instruction, &last_throwaway_num );
  mosh_transport_instruction_get_protocol_version( last_instruction, &last_protocol_version );
  
  if ( inst_old_num != last_old_num || inst_new_num != last_new_num || 
       inst_ack_num != last_ack_num || inst_throwaway_num != last_throwaway_num ||
       inst_protocol_version != last_protocol_version || last_MTU != MTU ) {
    next_instruction_id++;
  }

  // Serialize the instruction
  std::vector<uint8_t> buffer( 65536 ); // Large buffer for serialization
  size_t actual_size;
  if ( !mosh_transport_instruction_serialize( inst, buffer.data(), buffer.size(), &actual_size ) ) {
    // Serialization failed
    return std::vector<Fragment>();
  }
  
  std::string payload = get_compressor().compress_str( std::string( reinterpret_cast<char*>(buffer.data()), actual_size ) );
  
  // Update last_instruction by copying the current one
  mosh_transport_instruction_destroy( last_instruction );
  last_instruction = mosh_transport_instruction_create();
  
  if ( mosh_transport_instruction_get_protocol_version( inst, &inst_protocol_version ) ) {
    mosh_transport_instruction_set_protocol_version( last_instruction, inst_protocol_version );
  }
  if ( mosh_transport_instruction_get_old_num( inst, &inst_old_num ) ) {
    mosh_transport_instruction_set_old_num( last_instruction, inst_old_num );
  }
  if ( mosh_transport_instruction_get_new_num( inst, &inst_new_num ) ) {
    mosh_transport_instruction_set_new_num( last_instruction, inst_new_num );
  }
  if ( mosh_transport_instruction_get_ack_num( inst, &inst_ack_num ) ) {
    mosh_transport_instruction_set_ack_num( last_instruction, inst_ack_num );
  }
  if ( mosh_transport_instruction_get_throwaway_num( inst, &inst_throwaway_num ) ) {
    mosh_transport_instruction_set_throwaway_num( last_instruction, inst_throwaway_num );
  }
  
  const char* diff_data;
  size_t diff_len;
  if ( mosh_transport_instruction_get_diff( inst, &diff_data, &diff_len ) ) {
    mosh_transport_instruction_set_diff( last_instruction, diff_data, diff_len );
  }
  
  const char* chaff_data;
  size_t chaff_len;
  if ( mosh_transport_instruction_get_chaff( inst, &chaff_data, &chaff_len ) ) {
    mosh_transport_instruction_set_chaff( last_instruction, chaff_data, chaff_len );
  }
  
  last_MTU = MTU;
  uint16_t fragment_num = 0;
  std::vector<Fragment> ret;

  while ( !payload.empty() ) {
    std::string this_fragment;
    bool final = false;

    if ( payload.size() > MTU ) {
      this_fragment = std::string( payload.begin(), payload.begin() + MTU );
      payload = std::string( payload.begin() + MTU, payload.end() );
    } else {
      this_fragment = payload;
      payload.clear();
      final = true;
    }

    ret.push_back( Fragment( next_instruction_id, fragment_num++, final, this_fragment ) );
  }

  return ret;
}
