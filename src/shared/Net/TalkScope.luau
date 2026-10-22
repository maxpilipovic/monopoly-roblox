--!strict
-- Who can hear whom, in text chat and voice: players at the same game table talk among themselves
-- and nobody else, and everyone in the lobby talks together. The server marks each player at a
-- board with the Table attribute (their room's id) and clears it when they're back in the lobby.
-- On top of that each player can mute anyone for themselves.

local TalkScope = {}

TalkScope.ATTRIBUTE = "Table"

export type Talker = { id: number, table: number? }
-- listener user id -> the speakers they've muted
export type Mutes = { [number]: { [number]: boolean } }

function TalkScope.tableOf(player: Instance): number?
	local value = player:GetAttribute(TalkScope.ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
end

-- Both in the lobby (no table), or both at the same table.
function TalkScope.together(a: number?, b: number?): boolean
	return a == b
end

function TalkScope.isMuted(mutes: Mutes, listener: number, speaker: number): boolean
	local muted = mutes[listener]
	return muted ~= nil and muted[speaker] == true
end

-- Whether `listener` gets `speaker`'s messages and voice.
function TalkScope.hears(mutes: Mutes, listener: Talker, speaker: Talker): boolean
	return TalkScope.together(listener.table, speaker.table) and not TalkScope.isMuted(mutes, listener.id, speaker.id)
end

-- Everyone (but the speaker) who hears `speaker`, as user ids.
function TalkScope.listeners(mutes: Mutes, speaker: Talker, everyone: { Talker }): { number }
	local ids = {}
	for _, listener in everyone do
		if listener.id ~= speaker.id and TalkScope.hears(mutes, listener, speaker) then
			table.insert(ids, listener.id)
		end
	end
	return ids
end

return TalkScope
