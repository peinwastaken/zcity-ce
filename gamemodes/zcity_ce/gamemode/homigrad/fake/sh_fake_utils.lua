local PLAYER = FindMetaTable("Player")

function PLAYER:IsFakeRagdolled()
  return zc.GetFakeState(self) == zc.FAKE_STATE.ACTIVE
end