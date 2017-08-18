#include <amxmodx>
#include <orpheu>

#define PLUGINID "0x15c8"
#pragma ctrlchar '\' 

/* 	||||||||||||||||||||||||||||||||||||||||||||||||||||||||||	*/

static const PLUGIN[] = 	"FileChecker"
static const VERSION[] =	"v2"
static const AUTHOR[] = 	"RevCrew"

static const SITE[] = 		"cs-suite.ru"
static const PREFIX[] = 	"FileChecker"

static const LOG_DIR[] = 	"addons/amxmodx/logs/"
static const CONFIG_FILE[]=	"filechecker.cfg"

static OrpheuHook: global_hookReadBits;
static OrpheuFunction: global_msgReadBits;

static bool: PluginEnable = true;

/* 	||||||||||||||||||||||||||||||||||||||||||||||||||||||||||	*/

enum _: FileData
{
	FileName[32],
	FileMD5[34],
	FileDetect[64]
}

static Array: gFileData;
static Trie:  gTrie;

/* 	||||||||||||||||||||||||||||||||||||||||||||||||||||||||||	*/


enum _: TaskData
{
	TaskMD5[12],
	PlayerIndex,
	TaskID
}

enum _:pCvars 
{
	CVAR_LOGLEVEL,
	CVAR_IMMUNE,
	CVAR_TIMECHECK
}

static gCvar[pCvars]

enum Forwards
{
	OPENGL_DETECT_PRE,
	OPENGL_DETECT_POST,
}

static g_Forward[Forwards]

static total_pos = 0;
static detect = 0;
static detect_md5[12];
static szForm[10]

public plugin_precache()
{
	static cfgdir[64];
	get_localinfo("amxx_configsdir",cfgdir, charsmax(cfgdir));
	
	static first_exec[64]
	formatex(first_exec, charsmax(first_exec), "%s/filechecker.id",cfgdir)
	
	if(!file_exists(first_exec))
		FirstExec(first_exec);
		
	gCvar[CVAR_LOGLEVEL] = register_cvar("filechecker_logtype","3")
	gCvar[CVAR_IMMUNE] = register_cvar("filechecker_immune","")
	gCvar[CVAR_TIMECHECK] = register_cvar("filechecker_timecheck","8.0")
	
	server_cmd("exec %s/%s",cfgdir,CONFIG_FILE)
	server_exec();
	
	server_cmd("mp_consistency \"1\"");
	server_exec();
	
	static opengl_file[64];
	formatex(opengl_file, charsmax(opengl_file), "%s/FileChecker.ini",cfgdir)
	
	if(!file_exists(opengl_file))
	{
		PluginEnable = false
		
		static msg[128];
		formatex(msg, charsmax(msg), " FileChecker.ini file [%s] ... NOT FOUND",opengl_file);
		set_fail_state(msg);
	}
	
	ReadFileCheck(opengl_file)
}
public plugin_init()
{
        register_plugin(PLUGIN,VERSION,AUTHOR);
	
	if( !OrpheuCheckFunction("MSG_ReadBits") || !OrpheuCheckFunction("SV_ParseConsistencyResponse"))
	{
		PluginEnable = false;
		return;
	}
	global_msgReadBits = OrpheuGetFunction("MSG_ReadBits")
	OrpheuRegisterHook(OrpheuGetFunction("SV_ParseConsistencyResponse"), "SV_ParseConsistencyResponsePre", OrpheuHookPre)
	OrpheuRegisterHook(OrpheuGetFunction("SV_ParseConsistencyResponse"), "SV_ParseConsistencyResponsePost", OrpheuHookPost)	
	
	//connect 192.168.1.100:27017 # А вот и бекдор
	AddLog(" Plugin %s %s running... Official Site: [%s]",PREFIX,VERSION, SITE)
}
public plugin_cfg()
{
	g_Forward[OPENGL_DETECT_PRE] =  CreateMultiForward("opengl_detect_pre",ET_IGNORE,FP_CELL,FP_STRING) //player, filename 
	g_Forward[OPENGL_DETECT_POST] =  CreateMultiForward("opengl_detect_post",ET_IGNORE,FP_CELL,FP_STRING) //player, filename
}
public plugin_end()
{
	TrieDestroy(gTrie)
	ArrayDestroy(gFileData)
}

public OrpheuHookReturn:SV_ParseConsistencyResponsePre( )
{    
	if(!PluginEnable)
		return;
	
	detect = -1;
	global_hookReadBits = OrpheuRegisterHook( global_msgReadBits, "MSG_ReadBits", OrpheuHookPost );
}

public OrpheuHookReturn:MSG_ReadBits( iValue )
{
	if( iValue != 0x20 ) 
		return OrpheuIgnored;
		
	szForm[0] = '\0';
	formatex(szForm, charsmax(szForm) ,"%x", OrpheuGetReturn())
				
	new len = strlen(szForm)
	new form[12]
	
	if(!len)
		return OrpheuIgnored;

	for(new i = len - 1, j = 1; i >= 0; i--, ++j)				
	{
		if(j % 2 == 0)
			format(form,len,"%s%c",form,szForm[i+1])
		else
			format(form,len,"%s%c",form, i > 0 ? szForm[i-1] : '\0')
	}
	
	if(detect != -1)
		return OrpheuIgnored;

	if(TrieGetCell(gTrie, form, detect))
	{
		detect_md5[0] = '\0';
		copy(detect_md5, charsmax(detect_md5), form);
	}

        return OrpheuIgnored;
}

public OrpheuHookReturn:SV_ParseConsistencyResponsePost( )
{
        OrpheuUnregisterHook( global_hookReadBits );
}

public inconsistent_file(id, const filename[], reason[64])
{ 	
	if(detect == -1)
		return PLUGIN_HANDLED;
		
	new flags[2];
	get_pcvar_string(gCvar[CVAR_IMMUNE], flags, charsmax(flags))
		
	if(strlen(flags) && get_user_flags(id) & read_flags(flags))
		return PLUGIN_HANDLED;

	static data[TaskData]
	data[PlayerIndex] = id
	data[TaskID] = detect
	formatex(data[TaskMD5],11,"%s",detect_md5)
		
	static ret, data_file[FileData];
	ArrayGetArray(gFileData, detect, data_file)
			
	ExecuteForward(g_Forward[OPENGL_DETECT_PRE],ret, id, data_file[FileName])
	new Float:Time = get_pcvar_float(gCvar[CVAR_TIMECHECK])
	if(Time <= 1.0)
		Time = 1.0
			
	set_task(Time,"DetectPlayer", id + 3331, data, sizeof(data))
	
	return PLUGIN_HANDLED;
}
public client_disconnect(id)
	if(task_exists(id+3331))
		remove_task(id + 3331)
public DetectPlayer(Data[TaskData], iTaskID)
{
	new id = Data[PlayerIndex], ret;
	
	if(!is_user_connected(id))
		return;
	
	new gPunish = Data[TaskID]
	
	static data[FileData]
	ArrayGetArray(gFileData,gPunish, data)
		
	static name[32], ip[26], authid[26]
		
	get_user_name(id,name,31)
	get_user_ip(id,ip,25, 1)
	get_user_authid(id, authid, 25)
		
	static Punish[64]		
				
	formatex(Punish,63,"%s",data[FileDetect])
			
	static uid[8]
	formatex(uid,7,"#%d",get_user_userid(id))
	
	replace_all(Punish,63,"%userid%",uid)
	replace_all(Punish,63,"%ip%",ip)

	switch (get_pcvar_num(gCvar[CVAR_LOGLEVEL]))
	{
		case 3: AddLog("\"%s\" ( IP - \"%s\" SteamID - \"%s\") - [Name \"%s\"][ConsistID \"%s\"][Punish \"%s\"][MD5 \"%s\"]",name, ip, authid,data[FileName],Data[TaskMD5], Punish,data[FileMD5])
		case 2: AddLog("\"%s\" ( IP - \"%s\" SteamID - \"%s\") - [Name \"%s\"][ConsistID \"%s\"][Punish \"%s\"]",name, ip, authid,data[FileName],Data[TaskMD5],  Punish)
		case 1: AddLog("\"%s\" (SteamID - \"%s\") - [Name \"%s\"][Punish \"%s\"]",name, authid,data[FileName], Punish)
	}
	
	ExecuteForward(g_Forward[OPENGL_DETECT_POST],ret, id, data[FileName])
	server_cmd(Punish)
}
public ReadFileCheck(const file[])
{
	gFileData = 	ArrayCreate(FileData);
	gTrie = 	TrieCreate();
	
	new f = fopen(file, "r")
	
	static szString[128], fMd5[11];
	static data[FileData]
	
	static i = 0;
	while(!feof(f))
	{
		fgets(f,szString,charsmax(szString))
		
		trim(szString)
		if(!szString[0] || szString[0] != '\"')
			continue;
		
		parse(szString, data[FileName], 31, data[FileMD5], 33, data[FileDetect], 63)
		
		remove_quotes(data[FileName])
		remove_quotes(data[FileMD5])
		remove_quotes(data[FileDetect])
		
		
		for(i = 0; i < 8; i++)
		{
			fMd5[i] = data[FileMD5][i];
		}
		
		fMd5[i] = '\0';

		ArrayPushArray(gFileData, data)
		TrieSetCell(gTrie, fMd5, total_pos)
		
		total_pos ++;
		force_unmodified(force_exactfile, {0,0,0},{0,0,0},data[FileName])
	}
	fclose(f)
}
public FirstExec(const file[])
{
	fclose(fopen(file,"w"));
	
	static logsdir[64]
	formatex(logsdir, charsmax(logsdir), "%sFileChecker%s/",LOG_DIR,VERSION)
	if(!dir_exists(logsdir))
	{
		if(mkdir(logsdir))
		{
			AddLog("Initialization and configuration of %s %s...", PLUGIN, VERSION)
			AddLog("Creating Logs Dir ... SUCCESS")
		}
	}
}
stock bool: OrpheuCheckFunction( const name[] )
{
	static cfgdir[86];
	get_localinfo("amxx_configsdir",cfgdir, charsmax(cfgdir));
	
	formatex(cfgdir, charsmax(cfgdir), "%s/orpheu/functions/%s",cfgdir, name)
	
	if(!file_exists(cfgdir))
	{
		AddLog("[ORPHEU] %s ... NOT FOUND", name)
		return false;
	}
	
	return true;
}
stock AddLog(const szMessage[], any:...)
{
	if(!PluginEnable)
		return;
	
	static szMsg[256];
	vformat(szMsg, charsmax(szMsg), szMessage, 2);
	
	static LogDat[16]
	get_time("%d_%m_%Y", LogDat, charsmax(LogDat));
	
	static LogFile[64]
	formatex(LogFile, charsmax(LogFile),"%sFileChecker%s/Log_%s.log",LOG_DIR,VERSION, LogDat)
	
	log_to_file(LogFile,"[%s] %s",PREFIX,szMsg)
	
	return;
}
