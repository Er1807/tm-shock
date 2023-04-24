[Setting min=0 max=100 name="Threshold" description="How sensitive the Bonk! detection is. If you get many false positives, increase this value."]
float bonkThreshold = 64.f;

[Setting min=0 max=60000 name="Debounce" description="Length (in ms) to cool down before sending additional shocks."]
uint bonkDebounce = 500;

[Setting name="Username of your Pishock account"]
string piShockUsername = "";
[Setting password name="ApiKey of your Pishock account"]
string piShockApiKey = "";
[Setting password name="Sharecode of your Pishock shocker"]
string piShockSharecode = "";
[Setting min=0 max=100 name="The strength of the shock"]
uint piShockStrength = 20;
[Setting min=0 max=15 name="The duration of the shock"]
uint piShockDuration = 1;

void Main() {
	while (true) {
		step();
		yield();
	}
}

float prev_speed = 0;
uint64 lastBonk = 0;

float bonkTargetThresh = 0.f;
float detectedBonkVal = 0.f;

void step() {
	try {
	if (VehicleState::GetViewingPlayer() is null) return;
	} catch { return; }
	CSceneVehicleVisState@ vis = VehicleState::ViewingPlayerState();
	if (vis is null) return;

	if (GetApp().CurrentPlayground is null || (GetApp().CurrentPlayground.UIConfigs.Length < 1)) return;
	if (GetApp().CurrentPlayground.UIConfigs[0].UISequence != CGamePlaygroundUIConfig::EUISequence::Playing) return;
	
#if TMNEXT
  	if (vis.RaceStartTime == 0xFFFFFFFF) { // in pre-race mode
		prev_speed = 0;
		lastBonk == Time::Now;
	}
#elif MP4||TURBO
  	if (vis.FrontSpeed == 0) { // in pre-race mode hopefully
		prev_speed = 0;
		lastBonk == Time::Now;
	}
#endif
	
	float speed = getSpeed(vis);
	float curr_acc;
	try {
		curr_acc = Math::Max(0, (prev_speed - speed) / (g_dt/1000));
	} catch {
		curr_acc = 0;
	}
	prev_speed = speed;
	
	if (speed < 0) {
		speed *= -1.f;
		curr_acc *= -1.f;
	}
	bonkTargetThresh = (bonkThreshold + prev_speed * 1.5f);
	bool mainBonkDetect = curr_acc > bonkTargetThresh;
#if TMNEXT
	if (mainBonkDetect && !vis.IsTurbo) bonk(curr_acc);
#elif MP4||TURBO
	if (mainBonkDetect) bonk(curr_acc); // IsTurbo not reported by VehicleState wrapper
#endif
}

void bonk(const float &in curr_acc) {
	detectedBonkVal = curr_acc;
	trace("DETECTED BONK @ " + Text::Format("%f", detectedBonkVal));
	if ((lastBonk + bonkDebounce) > Time::Now) return;
	
	lastBonk = Time::Now;
	startnew(CallAPI);
}

void CallAPI(){
	Json::Value payload = Json::Object();
    payload["Username"] = piShockUsername;
    payload["Name"] = "TM-Shocker";
    payload["Code"] = piShockSharecode;
    payload["Duration"] = Text::Format("%d", piShockDuration);
    payload["Intensity"] = Text::Format("%d", piShockStrength) ;
    payload["Op"] = "0"; // shock
    payload["Apikey"] = piShockApiKey;
	trace(Json::Write(payload) );
    Net::HttpRequest@ request =  Net::HttpPost("https://do.pishock.com/api/apioperate/", Json::Write(payload), "application/json");
    while (!request.Finished()) {
		yield();
		sleep(50);
    }

		
	trace("Shock send" + Text::Format("%d", request.ResponseCode()) );
}

float g_dt = 0;
void Update(float dt)
{
	g_dt = dt;
}

float getSpeed(CSceneVehicleVisState@ vis) {
#if TMNEXT||TURBO
	return vis.WorldVel.Length();
#elif MP4
	return vis.FrontSpeed;
#endif
}
