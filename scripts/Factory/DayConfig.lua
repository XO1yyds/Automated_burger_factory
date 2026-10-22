-- V0.6 campaign tuning. This is the runtime source of truth, not scattered UI constants.
local Config={}
Config.Prices={cooker=60,assembler=60,buffer=20,storage=60,junction=10,isolator_straight=15,isolator_corner=15,belt=1,cable=1,terminal=100,delivery_component=80}
Config.UnlockDay={workshop=1,cooker=2,supply_raw=2,supply_bun=2,supply_lettuce=2,assembler=3,conveyor=4,belt=4,buffer=4,
    junction=5,isolator_straight=5,isolator_corner=5,storage=6,cable=6,network=6,terminal=7,delivery_component=8,manage=2}
Config.Supplies={supply_raw='raw_beef',supply_bun='bun',supply_lettuce='lettuce'}
Config.SupplyIds={supply_raw='ws_raw',supply_bun='ws_bun',supply_lettuce='ws_lettuce'}
Config.Days={
    {seconds=180,orders={1,1,1,1},limit=2,first=20,interval=35,goal=3,title='手工开店',lesson='取料→空手长按煎肉3秒→组合→交付区→收银。',objective='manual'},
    {seconds=210,orders={1,1,1,1,1},limit=2,first=15,interval=35,goal=4,title='机器替你煎肉',lesson='进入车间，购买烹饪台。三槽并行加工，玩家手搬、回店组合。',objective='cooker'},
    {seconds=240,orders={1,2,1,2,1,2},limit=3,first=15,interval=30,goal=7,title='两台机器成一线',lesson='购买自动组合台，手搬胚、熟肉和生菜，让单功能机器组成流程。',objective='assembler'},
    {seconds=240,orders={2,2,2,2,2,2},limit=3,first=15,interval=30,goal=10,title='第一次自动搬运',lesson='先接供肉口→烹饪台→组合台，手补胚和生菜；缓存台可接成品。',objective='belt'},
    {seconds=270,orders={2,2,2,2,3,3,3},limit=3,first=15,interval=30,goal=14,title='完整传送带工厂',lesson='补齐三种原料和成品输送，使用接口，检查等料与回堵。',objective='conveyor_burger'},
    {seconds=270,orders={2,2,3,3,3,3,4},limit=4,first=15,interval=30,goal=16,title='让设备共享信息',lesson='库存、电缆与网络查询开放。连接建筑，查看网络；没有任务时电缆不运输。',objective='network'},
    {seconds=300,orders={3,3,3,3,3,3,3,3},limit=4,first=15,interval=30,goal=20,title='按需求自动生产',lesson='下单组件绑定库存，接入原料和两种机器；先下1件，再批量下单并查看实际到货。',objective='arrival'},
    {seconds=300,orders={3,3,3,3,4,4,4,4},limit=4,first=15,interval=30,goal=23,title='把交付接入工厂',lesson='下单终端→输出带→另一个交付缓存/库存→收银。两组件不能占同一个宿主。',objective='delivery'},
    {seconds=330,orders={4,4,4,4,4,4,4,4,4},limit=5,first=15,interval=30,goal=29,title='寻找真正的瓶颈',lesson='尝试增加组合设备、分流与成品缓冲，对比等料、加工和堵塞时间。',objective='parallel'},
    {seconds=360,orders={4,4,4,4,5,5,5,5,6,6},limit=6,first=15,interval=30,goal=40,title='你的汉堡工厂',lesson='用已建工厂接更大的单，调整瓶颈、补足产量，完成十天经营。',objective='factory'},
}
function Config.Day(day)
    local d=assert(Config.Days[day],'Invalid campaign day')
    return d
end
function Config.Total(d) local n=0; for _,v in ipairs(d.orders) do n=n+v end; return n end
return Config
