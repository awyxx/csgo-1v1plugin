#pragma semicolon 1
#define DEBUG
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colors>  
#include <halflife>

#pragma newdecls required

// shit no one cares about
#define TAG "\x01[\x0Eawyx 1v1\x01]"
public Plugin myinfo = 
{
	name = "1v1 plugin",
	author = "awyx",
	description = "Choose 2 players and fight! ",
	version = "1.3",
	url = "https://steamcommunity.com/id/sleepiest/"
};


// global vars
int player1, player2, p1, p2, rounds;
int roundsWon_p1 = 0, roundsWon_p2 = 0;
bool match, draw, playerkilled, hpRule;
bool beingUsed = false; // menu being used by another player


public void OnPluginStart()
{
	RegAdminCmd("sm_1v1", Main, ADMFLAG_GENERIC);
	RegAdminCmd("sm_cancel1v1", Cancel1v1, ADMFLAG_GENERIC);
	
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath);	
	HookEvent("round_end", OnRoundEnd);
}

// current map
char mapname[128];
public void OnMapStart() 
{ 
    GetCurrentMap(mapname, sizeof(mapname));
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast) 
{ 
	if (match){
		playerkilled = false;
		draw = false;
		info1v1();
	}
}

public void OnRoundEnd(Handle event, const char[] name, bool dontBroadcast) 
{ 
	if (match)
	{
		if (!playerkilled)
		{
			if (hpRule) // hp rule = wins the round the player which has more hp
			{
				int vidap1 = GetClientHealth(p1);
				int vidap2 = GetClientHealth(p2);
			
				if (vidap1 > vidap2)
				{
					roundsWon_p1++;
					PrintToChatAll("%s \x0B%N HP: \x05%d \x03|| \x07%N HP: \x05%d", TAG, p1, vidap1, p2, vidap2);
					PrintToChatAll("%s \x0A%N has won the round due to having more HP. ( \x02%d \x0A)", TAG, p1, vidap1);
				}
				else if (vidap1 < vidap2)
				{
					roundsWon_p2++;
					PrintToChatAll("%s \x0B%N HP: %d \x03|| \x07%N HP: %d", TAG, p1, vidap1, p2, vidap2);
					PrintToChatAll("%s \x0A%N has won the round due to having more HP. ( \x02%d \x0A)", TAG, p2, vidap2);
				}
				else if (vidap1 == vidap2){
					draw = true;
					PrintToChatAll("%s \x0ARound draw due to both players having the same health. ( %d - %d )", TAG, vidap1, vidap2);
				}
				
				if ((roundsWon_p1 == rounds) || (roundsWon_p2 == rounds))
				{
					RemoveCommandListener(ChangeTeam, "jointeam");
					PrintToChatAll("\%s \x03---------- GG ----------", TAG);
					
					if (roundsWon_p1 == rounds){ // p1 wins
						for (int x = 0; x < 3; x++) {
							PrintToChatAll("%s \x0B%N \x01has beaten \x07%N \x01( \x0B%d \x01- \x07%d\x01 ) ", TAG, p1, p2, roundsWon_p1, roundsWon_p2);
						}
					}
					
					if (roundsWon_p2 == rounds){ // p2 wins
						for (int y = 0; y < 3; y++) { 
							PrintToChatAll("%s \x07%N \x01has beaten \x0B%N \x01( \x07%d \x01- \x0B%d\x01 ) ", TAG, p2, p1, roundsWon_p2, roundsWon_p1);
						}
					}
					
					p1 = p2 = player1 = player2 = -1;
					rounds = roundsWon_p1 = roundsWon_p2 = 0;
					match = false;
				}	
			}
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (match)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		int victimId = event.GetInt("userid");
		int victim = GetClientOfUserId(victimId);
		int teamVictim = GetClientTeam(victim);

		if (teamVictim == CS_TEAM_T) 
			roundsWon_p1++;

		else if (teamVictim == CS_TEAM_CT)
			roundsWon_p2++;
		
		playerkilled = true;
		
		if ((roundsWon_p1 == rounds) || (roundsWon_p2 == rounds))
		{
			RemoveCommandListener(ChangeTeam, "jointeam");
			PrintToChatAll("%s \x03---------- GG ----------", TAG);
			SetHudTextParams(-1.0, 0.1, 10.1, 255, 255, 0, 2, 0);
			if (roundsWon_p1 == rounds)
			{
				for (int x = 0; x < 3; x++){
					PrintToChatAll("%s \x0B%N \x01has beaten \x07%N \x01( \x0B%d \x01- \x07%d\x01 ) ", TAG, p1, p2, roundsWon_p1, roundsWon_p2);
				}
				ShowHudText(client, 2, "%N has won!", p1);
			}
			if (roundsWon_p2 == rounds)
			{
				for (int y = 0; y < 3; y++){ 
					PrintToChatAll("%s \x07%N \x01has beaten \x0B%N \x01( \x07%d \x01- \x0B%d\x01 ) ", TAG, p2, p1, roundsWon_p2, roundsWon_p1);
				}
				ShowHudText(client, 2, "%N has won!", p2);
			}
			
			p1 = p2 = player1 = player2 = -1;
			rounds = roundsWon_p1 = roundsWon_p2 = 0;
			match = false;
		}
	}
}

// cancel the plugin 
public Action Cancel1v1(int client, int args)
{
	PrintToChat(client, "%s \x07Match canceled!", TAG);
	
	p1 = p2 = player1 = player2 = -1;
	rounds = roundsWon_p1 = roundsWon_p2 = 0;
	match = playerkilled = draw = beingUsed = false;
	
	RemoveCommandListener(ChangeTeam, "jointeam");
	
	return Plugin_Stop; 
}

// first menu (Choose players)
public Action Main(int client, int args)
{
	if (match) {
		PrintToChat(client, "%s \x07There is already a match running.", TAG);
		return Plugin_Stop; 
	}
	
	if (beingUsed) // if some1 is using the menu...
	{
		PrintToChat(client, "%s \x07There is someone using the plugin already.", TAG);
		return Plugin_Stop;
	}
	
	PrintToChat(client, "%s \x07If you want to cancel the 1v1 match do \x04!cancel1v1", TAG);
	
	beingUsed = true;
	Menu menu = new Menu(MenuMain_Callback);
	menu.SetTitle("First to ? rounds");
	menu.AddItem("1", "1");
	menu.AddItem("2", "3");
	menu.AddItem("3", "5");
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuMain_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action) 
	{
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			rounds = StringToInt(item) * 2 - 1;
			hpRuleMenu(param1);
		}
		
		case MenuAction_End: { Cancel1v1(param1,param2); delete menu; }
	}
}


// menu hp rule (wins the round who was more hp)
public Action hpRuleMenu(int client)
{
	Menu menuHP = new Menu(MenuHP_Callback);
	menuHP.SetTitle("Do you want HP rule");
	menuHP.AddItem("0", "No");
	menuHP.AddItem("1", "Yes");
	menuHP.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHP_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action) 
	{
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "0"))
				hpRule = false;

			if (StrEqual(item, "1"))
				hpRule = true;
				
			menu1(param1);
		}
		
		case MenuAction_End: { Cancel1v1(param1,param2); delete menu; } 
	}
}


// menu player 1
public Action menu1(int client)
{
	Menu menuT1 = new Menu(MenuT1_Cb);
	menuT1.SetTitle("Player 1:");
	for(int id = 1; id < MAXPLAYERS; id++) 
	{
 		if(IsClientInGame(id))
 		{
     		char info[10], name[32];
     		IntToString(id, info, sizeof(info));
     		GetClientName(id, name, sizeof(name));
    		menuT1.AddItem(info, name);
 		}
 	}
 	menuT1.Display(client, MENU_TIME_FOREVER);
}

public int MenuT1_Cb(Menu menuT1, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32], name[MAX_NAME_LENGTH];
			menuT1.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
			int client = StringToInt(info);
			p1 = client;
			if(IsClientInGame(client))
			{
					player1 = client;
					CS_SwitchTeam(client, CS_TEAM_CT);
					PrintToChat(param1, "%s Player %N has been moved to \x0BCT", TAG, client);  
			}
			menu2(param1);
		}
		
		case MenuAction_End:{ Cancel1v1(param1,param2); delete menuT1; }
	}
}


// menu player 2
public Action menu2(int client)
{
	Menu menuT2 = new Menu(MenuT2_Cb);
	menuT2.SetTitle("Player 2:");
	for(int id = 1; id < MAXPLAYERS; id++) 
	{
 		if(IsClientInGame(id))
 		{
     		char info[32], name[32];
     		IntToString(id, info, sizeof(info));
     		GetClientName(id, name, sizeof(name));
     		
     		bool verificarid = false;
     		for (int x = 0; x < MAXPLAYERS; x++){
				if(id == player1){
					verificarid = true;
					break;
				}
     		}
     		
     		if(!verificarid)
				menuT2.AddItem(info, name);

    	}
 	}
 	menuT2.Display(client, 0);
}

public int MenuT2_Cb(Menu menuT2, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32], name[MAX_NAME_LENGTH];	
			menuT2.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
			int client = StringToInt(info);
			p2 = client;
			if (IsClientInGame(client))
			{
				player2 = client;
				CS_SwitchTeam(client, CS_TEAM_T);
				PrintToChat(param1, "%s Player %N has been moved to \x07T", TAG, client);  
			}
			SpecOut();
		}
		
		case MenuAction_End:{ Cancel1v1(param1,param2); delete menuT2; }		
	}	
}

// restart the round // spec the other players 
void SpecOut()
{
	beingUsed = false;
	match = true;
	
	if (match)
	{
		commands();
		AddCommandListener(ChangeTeam, "jointeam"); // blocks joining team 
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && i != player1 && i != player2)
				ChangeClientTeam(i, CS_TEAM_SPECTATOR);
		}
	}
}

// chat stuff (players, score and current map)
public void info1v1()
{
	if (match) {
		PrintToChatAll("\x01 \x04******************************");
		PrintToChatAll("\x01 \x0B%N \x01vs \x07%N", p1, p2); 
		PrintToChatAll("\x01 Score: %d - %d (first to \x05%d\x01)", roundsWon_p1, roundsWon_p2, rounds); 
		PrintToChatAll("\x01 Map: \x08%s", mapname);
		PrintToChatAll("\x01 \x04******************************");
	}
}

// avoid changing team
public Action ChangeTeam(int client, const char[] command, int args) 
{ 
	ChangeClientTeam(client, CS_TEAM_SPECTATOR); // if someone joins, they get moved
   	return Plugin_Stop; // blocks joining team
}  

// sum shit idk restart n stuff
void commands()
{
	if (match) {
		ServerCommand("mp_restartgame 1");
		ServerCommand("mp_limitteams 0");
		ServerCommand("mp_autoteambalance 0");
	}
}

public Action end()
{
	p1 = p2 = player1 = player2 = -1;
	rounds = roundsWon_p1 = roundsWon_p2 = 0;
	match = false;
}
