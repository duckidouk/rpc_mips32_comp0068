COMP0068 group project - RPC Rover - MIPS32 - UCL 

RPC must: 
  n = units

  1. Recharge: C n
  2. Solar align: S 2xn 
  3. Dock: D 2xn 
  4. traverse: T 3xn 
  5. Reset: R 
  6. Quit: Q 


  *Features:* 
  
- Startup: 
  - three parameters: 1. Drain Rate (PDR); 2. Max bat cap (MBC); 3. Initial bat charg (IBC)
- Charge lvl incr/decr based on op input 
- Commands entered in cap letters: ie 'C', 'R' etc...
- If battery = 0, rover is online. Reset required 
- Reset applied at any time during life cycle of mission
- If battery charge > MBC, battery charge = MBC + Error message 
- If  battery charge - T >= 0, battery charge = 0 + error msg

*clarifications*

- order event within 1 sec: command first, drain second. [t=mm:ss]
- Charge lvl (0<=Battery<=MBC)
- Cap error only when Bat - T < 0 
- When rover goes offline naturally, same error message 
- When offline, drain is suspended, only R and Q possible 
- R restores to defined IBC
- n must be >0. Command must be valid. Otherwise it is rejected 


*scenarios* remember every seconds drains by -2n 

1. Startup: Msg to configure mission [t = 0] 
2. Every secs, charge level decreases by 2n. 3 secs (6n) ellapses before operator  reads prompt [t=3] 
3. operator prompts c. [t=4]
4. s aligned: +6n [t=5]; d charging station +4n [t=6]
5. t -6n [t:7]
6. c +30n (capped at 20). Then -2n is applied for the second [t=8]
7. time elapsed: 7 seconds. -14n. [t=15]. Op t3 -> error message [t=16]
8. r [t=17]
9. q: mission end
