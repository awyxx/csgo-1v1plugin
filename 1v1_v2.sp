#pragma semicolon 1
#define DEBUG
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <halflife>

#pragma newdecls required


////// Shit no one cares about
#define TAG "\x0F[\x011v1\x0F]"
public Plugin myinfo = 
{
	name = "1v1 plugin",
	author = "roby/awyx", // s/o d34dspy
	description = "",
	version = "2",
	url = "https://steamcommunity.com/id/sleepiest/"
};


////// Vars
int g_iPlayer1, g_iPlayer2;
int g_iNRounds;
int g_iRoundsWon_p1 = 0, g_iRoundsWon_p2 = 0;

char g_sPlayer1Name[32] = "", g_sPlayer2Name[32] = "";
char g_sMap[64];

bool g_bIsBeingUsed = false;
bool g_bHpRule = true;
bool g_bFirstPick = false;
bool g_bIsMatchLive = false;
bool g_bPlayerKilled = false;
bool g_bEnd1v1 = false;
bool g_bPlayerLeft = false;
bool g_bIsRandom1v1 = false;

Handle g_menuRounds;
Handle g_menuHp;
Handle g_menuPlayer1;
Handle g_menuPlayer2;


public void OnPluginStart()
{
	//RegAdminCmd("sm_1v1", 		OnCommand_1v1, 		 ADMFLAG_GENERIC);
	//RegAdminCmd("sm_random1v1", OnCommand_Random1v1, ADMFLAG_GENERIC);
	//RegAdminCmd("sm_cancel1v1", OnCommand_Cancel1v1, ADMFLAG_GENERIC);
	
	RegConsoleCmd("sm_1v1", OnCommand_1v1);
	RegConsoleCmd("sm_1v1", OnCommand_Random1v1);
	RegConsoleCmd("sm_cancel1v1", OnCommand_Cancel1v1);
	
	HookEvent("round_start", 		Event_OnRoundStart);
	HookEvent("player_death", 		Event_PlayerDeath);	
	HookEvent("round_end", 			Event_OnRoundEnd);
	HookEvent("player_disconnect",  Event_PlayerDisconnect, EventHookMode_Pre);  
}



////// Commands
public Action OnCommand_1v1(int client, int args)
{
	if (g_bIsBeingUsed == false && g_bIsMatchLive == false) {
		Initialize();
		DisplayMenu(g_menuRounds, client, MENU_TIME_FOREVER);
	}
	else {
		PrintToChat(client, "%s \x07Error! There is %s", TAG, (g_bIsMatchLive ? "a match being played!":"someone using this command."));
	}
	return Plugin_Handled;
}

public Action OnCommand_Random1v1(int client, int args)
{
	if (g_bIsBeingUsed == false && g_bIsMatchLive == false) 
	{
		g_bIsRandom1v1 = true;
		Initialize();
		GetRandomPlayers();
		DisplayMenu(g_menuRounds, client, MENU_TIME_FOREVER);
	}
	else {
		PrintToChat(client, "%s \x07Error! There is %s", TAG, (g_bIsMatchLive ? "a match being played!":"someone using this command."));
	}
	return Plugin_Handled;
}

public Action OnCommand_Cancel1v1(int client, int args)
{
	Cancel1v1(client, args);
	return Plugin_Stop;
}

////// Functions
public void Initialize()
{
	g_bIsBeingUsed = true;
	GetCurrentMap(g_sMap, sizeof(g_sMap));

	// Initialize menus 
	g_menuRounds = CreateMenu(OnRoundsMenuDisplayed, MenuAction_Start|MenuAction_Select|MenuAction_End|MenuAction_Cancel);
	SetMenuTitle(g_menuRounds, "First to ? rounds");
	AddMenuItem(g_menuRounds, "3", "3");
	AddMenuItem(g_menuRounds, "5", "5");
    
	g_menuHp = CreateMenu(OnHpMenuDisplayed, MenuAction_Start|MenuAction_Select|MenuAction_End|MenuAction_Cancel);
	SetMenuTitle(g_menuHp, "HP rule");
	AddMenuItem(g_menuHp, "1", "ON");
	AddMenuItem(g_menuHp, "0", "OFF");
	
	if (!g_bIsRandom1v1) { // avoid creating menus that we wont use
		g_menuPlayer1 = CreateMenu(OnPlayersMenuDisplayed, MenuAction_Start|MenuAction_Select|MenuAction_End|MenuAction_Cancel);
		g_menuPlayer2 = CreateMenu(OnPlayersMenuDisplayed, MenuAction_Start|MenuAction_Select|MenuAction_End|MenuAction_Cancel);
	}
}

public void ShowPlayersMenu(int client, Handle menu)
{
	char menuPlayersTitle[16];
	Format(menuPlayersTitle, sizeof(menuPlayersTitle), "Player %s:", (g_bFirstPick ? "2":"1"));
	SetMenuTitle(menu, menuPlayersTitle);

	RemoveAllMenuItems(menu);
	AddMenuItem(menu, "0", "Random");
	for(int i = 1; i <= MaxClients; i++) 
	{
 		if(IsClientInGame(i))
 		{
			char info[4], name[32];
			IntToString(i, info, sizeof(info));
			GetClientName(i, name, sizeof(name));
			if (strcmp(name, g_sPlayer1Name) != 0)
				AddMenuItem(menu, info, name);
 		}
 	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void GetRandomPlayers()
{
	g_iPlayer1 = GetRandomInt(1, MaxClients);
	g_iPlayer2 = GetRandomInt(1, MaxClients);
	while (g_iPlayer2 == g_iPlayer1)
		g_iPlayer2 = GetRandomInt(1, MaxClients);
	GetClientName(g_iPlayer1, g_sPlayer1Name, sizeof(g_sPlayer1Name));
	GetClientName(g_iPlayer2, g_sPlayer2Name, sizeof(g_sPlayer2Name));
}

public void Start1v1()
{
	g_bIsBeingUsed = false;

	AddCommandListener(Event_OnChangeTeam, "jointeam");

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && i != g_iPlayer1 && i != g_iPlayer2)
			ChangeClientTeam(i, CS_TEAM_SPECTATOR);
	}

	ChangeClientTeam(g_iPlayer1, CS_TEAM_CT);
	ChangeClientTeam(g_iPlayer2, CS_TEAM_T);

	Commands(true, false);

	g_bIsMatchLive = true;

}

public void Cancel1v1(int client, int args)
{	
	if (g_bEnd1v1 || g_bPlayerLeft)
	{
		PrintToChatAll("%s \x04The match has ended! Players can join now!", TAG);
		RemoveCommandListener(Event_OnChangeTeam, "jointeam");
		Commands(false, true);
	}
	else if (g_bIsMatchLive) {
		PrintToChat(client, "%s \x04The match has been canceled!", TAG);
		RemoveCommandListener(Event_OnChangeTeam, "jointeam");
	}
	else if (g_bIsBeingUsed)	PrintToChat(client, "%s \x04The match has been canceled!", TAG);
	else						PrintToChat(client, "%s \x04There is no match!", TAG);

	ResetVars();
}

void ResetVars()
{
	if (g_bIsMatchLive)
		RemoveCommandListener(Event_OnChangeTeam, "jointeam");
	
	g_sPlayer1Name[0] = 0;
	g_sPlayer2Name[0] = 0;
	g_sMap[0] = 0;
	
	g_iPlayer1 = -1;
	g_iPlayer2 = -1;
	g_iNRounds = 0;
	g_iRoundsWon_p1 = 0; 
	g_iRoundsWon_p2 = 0;
	
	g_bIsBeingUsed = false;
	g_bHpRule = false;
	g_bFirstPick = false;
	g_bIsMatchLive = false;
 	g_bPlayerKilled = false;
 	g_bEnd1v1 = false;
	g_bPlayerLeft = false;
	g_bIsRandom1v1 = false;
}

public void Info1v1()
{
	if (g_bIsMatchLive) 
	{
		PrintToChatAll("%s", "\x01[\x0Eroby 1v1 plugin\x01]");
		PrintToChatAll("\x01 \x04************************************************************");
		PrintToChatAll("\x01 \x03Match: \x0C%s \x01vs \x0F%s", g_sPlayer1Name, g_sPlayer2Name); 
		PrintToChatAll("\x01 \x03Score: \x0C%d \x01- \x0F%d", g_iRoundsWon_p1, g_iRoundsWon_p2); 
		PrintToChatAll("\x01 \x03First to: \x05%d rounds\x01", g_iNRounds); 
		PrintToChatAll("\x01 \x03Map: \x05%s", g_sMap);
		PrintToChatAll("\x01 \x03HP Rule: \x05%s", g_bHpRule ? "ON":"OFF");
		PrintToChatAll("\x01 \x04************************************************************");
	}
}

public void Commands(bool matchStart, bool matchEnd)
{
	if (matchStart)
	{
		ServerCommand("mp_restartgame 3");
		ServerCommand("mp_teammates_are_enemies 0");
		ServerCommand("mp_forcecamera 1");
		ServerCommand("mp_force_pick_time 9999");
		ServerCommand("mp_maxrounds 50");
	}
	else if (matchEnd) {
		ServerCommand("mp_restartgame 3");
		ServerCommand("mp_forcecamera 0");
		ServerCommand("mp_teammates_are_enemies 1");
	}
}

public Action WaitStart1v1(Handle timer)
{
	Start1v1();
}

public Action PrintShit(Handle timer)
{
	for (int x = 0; x < 3; x++)
		PrintToChatAll("%s \x04A 1v1 match is about to start -> \x04[\"\x0C%s\" \x01vs \"\x0F%s\"\x04]", TAG, g_sPlayer1Name, g_sPlayer2Name);
}

////// Events
public Action Event_OnChangeTeam(int client, const char[] command, int args) 
{
	ChangeClientTeam(client, CS_TEAM_SPECTATOR);
	PrintToChat(client, "%s \x04Wait until the 1v1 match ends!", TAG);
	return Plugin_Stop;
}

public void Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast) 
{ 
	if (g_bIsMatchLive)
		Info1v1();
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bIsMatchLive)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (client == g_iPlayer1 || client == g_iPlayer2)
		{
			g_bPlayerLeft = true;
			PrintToChatAll("%s \x0FPlayer have disconnected! 1v1 canceled.", TAG);
			Cancel1v1(0,0);
		}
	}
}  


public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bIsMatchLive)
	{
		int iVictim = GetClientOfUserId(event.GetInt("userid"));
		int iTeamVictim = GetClientTeam(iVictim);

		if      (iTeamVictim == CS_TEAM_T) 	g_iRoundsWon_p1++;
		else if (iTeamVictim == CS_TEAM_CT)	g_iRoundsWon_p2++;

		g_bPlayerKilled = true;

	}
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bIsMatchLive)
	{
		if (!g_bPlayerKilled)
		{
			if (g_bHpRule)
			{
				int iHealthPlayer1 = GetClientHealth(g_iPlayer1);
				int iHealthPlayer2 = GetClientHealth(g_iPlayer2);
				bool bWhoWon; // Who won the round -> 0/false = player 1 ;;; 1/true = player2
				bool draw = false;

				PrintToChatAll("%s \x0B%s HP: \x0C%d \x01/// \x07%s HP: \x0F%d\x01", TAG, g_sPlayer1Name, iHealthPlayer1, g_sPlayer2Name, iHealthPlayer2);

				if (iHealthPlayer1 > iHealthPlayer2) {
					g_iRoundsWon_p1++;
					bWhoWon = false;
				}
				else if (iHealthPlayer1 < iHealthPlayer2) {
					g_iRoundsWon_p2++;
					bWhoWon = true;
				}
				else if (iHealthPlayer1 == iHealthPlayer2)
					draw = true;

				char sPlayerName[40], sPlayerHealth[8];
				Format(sPlayerName, sizeof(sPlayerName), "%s%s", bWhoWon ? "\x0F":"\x0C", bWhoWon ? g_sPlayer2Name:g_sPlayer1Name);
				Format(sPlayerHealth, sizeof(sPlayerHealth), "%s%d", bWhoWon ? "\x0F":"\x0C", bWhoWon ? iHealthPlayer2:iHealthPlayer1);
				
				if (!draw)
					PrintToChatAll("%s %s \x04has won the round due to having more HP -> (%s\x04)", TAG, sPlayerName, sPlayerHealth);
			}
			else	
				PrintToChatAll("%s \x04Round draw!", TAG);
		}

		bool bPlayer1Win = g_iRoundsWon_p1 == g_iNRounds;
		bool bPlayer2Win = g_iRoundsWon_p2 == g_iNRounds;
		bool bAnyWin = bPlayer1Win || bPlayer2Win;
		
		if (bAnyWin)
		{
			PrintToChatAll("\x01 \x04************************************************************");
			for (int x = 0; x < 3; x++)
			{
				PrintToChatAll("\x01 \x0B%s \x01has beaten \x07%s \x01(\x0B%d \x01- \x07%d\x01) ", 
                	bPlayer1Win ? g_sPlayer1Name : g_sPlayer2Name, 
                	bPlayer1Win ? g_sPlayer2Name :g_sPlayer1Name, 
                	bPlayer1Win ? g_iRoundsWon_p1 : g_iRoundsWon_p2, 
                	bPlayer1Win ? g_iRoundsWon_p2 : g_iRoundsWon_p1);
			}
			PrintToChatAll("\x01 \x04************************************************************");
			
			g_bEnd1v1 = true;

			Cancel1v1(0, 0);
		}

		g_bPlayerKilled = false;
	}
}

public void OnMapStart()
{
	ResetVars();
}

////// Menu Handlers
public int OnRoundsMenuDisplayed(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select: {
			char item[4];
			GetMenuItem(g_menuRounds, param2, item, sizeof(item));
			g_iNRounds = view_as<int>(StringToInt(item));
			DisplayMenu(g_menuHp, param1, MENU_TIME_FOREVER);
		}

		case MenuAction_End: {
			delete menu;
		}

		case MenuAction_Cancel: {
			Cancel1v1(param1, 0);
		}
	}

	return 0;
}

public int OnHpMenuDisplayed(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select: {
			char item[4];
			GetMenuItem(g_menuHp, param2, item, sizeof(item));
			g_bHpRule = view_as<bool>(StringToInt(item));
			if (!g_bIsRandom1v1)
				ShowPlayersMenu(param1, g_menuPlayer1);
			else {
				PrintToChatAll("%s \x04Picking random players....", TAG);
				CreateTimer(3.0, PrintShit);
				Start1v1();
			}
		}

		case MenuAction_End: {
			delete menu;
		}

		case MenuAction_Cancel: {
			Cancel1v1(param1, 0);
		}
	}

	return 0;
}

public int OnPlayersMenuDisplayed(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select: {
			char item[4], name[32];
			menu.GetItem(param2, item, sizeof(item), _, name, sizeof(name));

			if (!g_bFirstPick) 
			{
				g_iPlayer1 = StringToInt(item);
				g_sPlayer1Name = name;
				g_bFirstPick = true;
				ShowPlayersMenu(param1, g_menuPlayer2);
			}	
			else 
			{
				g_iPlayer2 = StringToInt(item);
				g_sPlayer2Name = name;
				
				for (int x = 0; x < 3; x++)
					PrintToChatAll("%s \x03A \x011v1 \x03match is about to start -> \x01(\x0C%s \x01vs \x0F%s\x01)", TAG, g_sPlayer1Name, g_sPlayer2Name);
				CreateTimer(3.0, WaitStart1v1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}

		case MenuAction_Cancel: {	
			Cancel1v1(param1, 0);
		}
	}

	return 0;
}
