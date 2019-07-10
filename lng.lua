--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

DEF_SERVERNAME     = 'A minecraft server'
DEF_SERVERMOTD     = 'This server uses LuaClassic'

TMR_ERR            = 'timer %q error: %s'

CON_INGAMECMD      = 'This command can\'t be called from console'
CON_LJVER          = 'Server requires LuaJIT >= 2.0.0-beta11'
CON_SAVESUCC       = 'Configuration has been saved successfully'
CON_HELP           = 'For help, type "help" or "?"'
CON_START          = 'Starting LuaClassic server'
CON_SAVEERR        = 'Configuration save has failed!'
CON_BINDSUCC       = 'Server started on %s:%d'
CON_WLOADERR       = 'No worlds loaded'
CON_SVDAT          = 'Saving data'
CON_BANLIST        = 'Loading banlist'
CON_WSAVE          = 'Saving worlds'
CON_SVSTOP         = 'Server stopped'
CON_WLOAD          = 'Loading worlds'
CON_USE            = 'Usage: %s'

CU_STOP            = 'stop - Stop the server'
CU_LEXEC           = '#<lua code> - Run lua code'
CU_RESTART         = 'restart - Restart the server'
CU_HELP            = 'help - Shows this list of commands'
CU_SAY             = 'say <message> - Send a message to chat'
CU_KICK            = 'kick <player> [reason] - Kick player'
CU_LIST            = 'list - Shows a list of loaded worlds'
CU_ADDPERM         = 'addperm <key> <permission> - Give permission'
CU_SEED            = 'seed [worldname] - Shows the seed of the world'
CU_DELPERM         = 'delperm <key> <permission> - Delete permission'
CU_TP              = 'tp <player> <to> - Teleport a player to another player'
CU_REGEN           = 'regen <world> [generator] [seed] - Regenerate specified world'
CU_PUT             = 'put <playername> <worldname> - Teleport player to specified world'
CU_WEATHER         = 'weather <world/weather type> [weather type] - Sets weather in specified world'
CU_TIME            = 'time <world/preset name> [preset name] - Sets time in specified world'

IE_MSG             = 'Internal server error: %s'
IE_UE              = 'Unexpected error'
IE_LE              = 'Lua error'

ST_OFF             = '&cdisabled&f'
ST_ON              = '&aenabled&f'
ST_NO              = '&cNO&f'
ST_YES             = '&aYES&f'

SD_HDRERR          = 'Invalid header'
SD_IOERR           = 'Can\'t open playerdata %q for %s! (%s)'
SD_ERR             = '%s\'s data file corrupted: %s'

KICK_PDATAERR      = 'PlayerData reading error, try to reconnect in a few seconds'
KICK_CONNREJ       = 'Server rejected your connection attempt'
KICK_CPESEQERR     = 'Packet 0x10 not received before 0x11'
KICK_CPEEXTCOUNT   = 'Invalid CPE extensions count received'
KICK_SVERR         = 'Server has gotten an unprotected lua error'
KICK_PROTOVER      = 'Invalid protocol version'
KICK_INVALIDPACKET = 'Invalid packet received'
KICK_MAPTHREADERR  = 'Error in mapsend thread'
KICK_NOREASON      = 'Kicked without reason'
KICK_SVRST         = 'Server is restarting'
KICK_NAMETAKEN     = 'This nickname is taken'
KICK_AUTH          = 'Authorization Error'
KICK_SVSTOP        = 'Server stopped'
KICK_SFULL         = 'Server is full'
KICK_TIMEOUT       = 'Timed out'

MESG_DONE          = 'done'
MESG_DONEIN        = 'done in %.3fms'
MESG_EXEC          = 'Executed'
MESG_ERROR         = 'Error: %s'
MESG_EXECRET       = 'Executed: %s'
MESG_PLAYERNF      = 'Player not found'
MESG_PLAYERNFA     = 'Player %q not found'
MESG_PERMERROR     = 'You do not have &c%s&f permission.'
MESG_LEVELLOAD     = 'Please wait, the server is loading this level...'
MESG_CONN          = 'Player %s connected to server'
MESG_DISCONN       = 'Player %s disconnected from server (%s)'
MESG_WORDISCONN    = 'Player %s disconnected from server'
MESG_UNKNOWNCMD    = 'Unknown command'
MESG_NOTWSCONN     = 'Not a WebSocket request'

CMD_WMODE          = 'Readonly mode %s for &a%s'
CMD_SVINFO         = 'Server runned on %s %s with %s\nRam used: %.3fMB'
CMD_TIMEPRESETNF   = 'Time preset not found'
CMD_TIMEDISALLOW   = 'Time changing not allowed in the nether'
CMD_TIMECHANGE     = 'Time in &a%s&f changed to &e%s'
CMD_SELMODE        = 'Selection mode %s'
CMD_SELCUBOID      = 'Select cuboid first'
CMD_CRPORTAL       = 'Portal created'
CMD_AEPORTAL       = 'Portal with the same name already exists'
CMD_RMPORTAL       = 'Portal removed'
CMD_NEPORTAL       = 'This portal not exists'
CMD_SPAWNSET       = 'Spawnpoint created'
CMD_BLOCKID        = 'Invalid block ID'
CMD_WORLDLST       = 'Loaded worlds:'
CMD_TPDONE         = 'Teleported'
CMD_GENERR         = 'Error in generator: %s'
CMD_WTCHANGE       = 'Weather in &a%s&f changed to &e%s'
CMD_WHISPER        = 'Message from %s: %s'
CMD_WHISPERSUCC    = 'Message sent'
CMD_WHISPERSELF    = 'You can not send a private message to yourself'
CMD_WTINVALID      = 'Invalid weather type'
CMD_WTCURR         = 'At this moment weather is &e%s&f in &a%s'
CMD_SEED           = 'Seed: %d'
CMD_UPTIME         = 'Uptime: %dd %dh %dm %ds'
CMD_CANCELRST      = '&a***&f Restart cancelled'
CMD_RSTTMR         = '&c***&f Server will restart in %d seconds!'
CMD_PLISTHDR       = 'Players online %d:'
CMD_PLISTROW       = '\n%s (Is web client: %s)'
CMD_COPYMEMLIM     = 'Cuboid size limit exceeded'

DBG_INCOMINGCONN   = 'Incoming connection from'
DBG_NEWTHREAD      = 'New SendMap thread:'
DBG_SPAWNPLAYER    = 'Player spawned:'
DBG_DESPAWNPLAYER  = 'Player despawned:'
DBG_DESTROYPLAYER  = 'Player destroyed:'
DBG_NEWTIMER       = 'New timer:'
DBG_STOPTIMER      = 'Timer stopped:'
DBG_PAUSETIMER     = 'Timer paused:'
DBG_RESUMETIMER    = 'Timer resumed:'
DBG_GMLOAD         = 'gmLoad:'

WORLD_RO           = '&cThis world is in read-only mode'
WORLD_NE           = 'This world does not exists'
WORLD_TOOBIGDIM    = 'World dimensions are too big'
WORLD_LOCKED       = 'This world can\'t be regenerated now. Try again later.'
