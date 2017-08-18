/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <ColorChat>

/*	
	OpenGL FileChecker: Forwards | Edition 2014 - Version 1.0
	AMX Mod X Plugin
	Copyright (C) 2014-2015  <CS-Suite>
	Our website "http://cs-suite.ru"

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
*/

#define PLUGIN "OpenGL FileChecker: Forwards"
#define VERSION "Edition 2014 | Version 1.0"
#define AUTHOR "<CS-Suite>"

#define HUD_MESSAGE_AND_CHAT
#define PRINT_INFO_CONSOLE_TO_PLAYER

forward opengl_detect_pre(const player, const file[])
forward opengl_detect_post(const player, const file[])

public plugin_init()	register_plugin(PLUGIN, VERSION, AUTHOR);

public opengl_detect_pre(const player, const file[])
{
  
}
public opengl_detect_post(const player, const file[])
{
	#if defined HUD_MESSAGE_AND_CHAT
	static name[32]; get_user_name(player,name,31)
	set_hudmessage(200,50, 50, -1.0, 0.2, 0, 0.5, 6.0, 1.0,1.0,3)
		
	static maxpl;
	if(!maxpl)	maxpl = get_maxplayers();
		
	for(new j = 0;j<maxpl;j++)
	{
		if( j!=player && is_user_connected(j))	
		{
			show_hudmessage(j,"^nOpenGL: FileChecker | Р’С‹РїСѓСЃРє 2014^nРќРёРєРЅРµР№Рј: ^"%s^"^nРћР±РЅР°СЂСѓР¶РµРЅ Р¤Р°Р№Р»: '%s'", name,file)
			ColorChat(j, BLUE, "[^4OpenGL | Р’С‹РїСѓСЃРє 2014^3] Р¤Р°Р№Р» ^4 '%s' ^3РѕР±РЅР°СЂСѓР¶РµРЅ Сѓ РёРіСЂРѕРєР°^4 '%s'",file,name )
		}
	}
	#endif
	
	#if defined PRINT_INFO_CONSOLE_TO_PLAYER
	console_print(player,"=============================")
	console_print(player,"WARNING")
	console_print(player,"Please Delete this file from your CS 1.6")
	console_print(player,"FileName: %s",file)
	#endif
}
