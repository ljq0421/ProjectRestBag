class_name TutorialDialogueCatalog
extends RefCounted

const FALLBACK := {
	"step_name": "当前引导",
	"dialogue": "别着急，先看看外婆留下的行动提示，再完成眼前这一步。",
	"action_hint": "完成当前引导目标。",
	"confirm_label": "我知道了",
}

const DIALOGUES := {
	"purchase": {
		"step_name": "备好种子",
		"dialogue": "新店开张，先别急着做甜品。我们从一袋水稻种子开始，把第一份原料亲手种出来。",
		"action_hint": "购买 1 份水稻种子。",
		"confirm_label": "去买种子吧",
	},
	"output": {
		"step_name": "种下水稻",
		"dialogue": "很好，种子已经备好了。光靠采购可撑不起一家店，我们去农场把它种下吧。",
		"action_hint": "在农场种下水稻种子，成熟后手动收获大米。",
		"confirm_label": "去农场看看",
	},
	"research": {
		"step_name": "研发米浆饮",
		"dialogue": "大米收好了。配上泉水，再用圆锅试一试，我们来研究店里的第一款商品。",
		"action_hint": "放入大米和泉水，选择圆锅，研发米浆饮。",
		"confirm_label": "开始研究吧",
	},
	"craft": {
		"step_name": "制作成品",
		"dialogue": "米浆饮的做法找到了。记住，知道配方只是开始，做出成品才能摆进橱窗。",
		"action_hint": "制作 1 次米浆饮。",
		"confirm_label": "做一份试试",
	},
	"list": {
		"step_name": "上架商品",
		"dialogue": "第一份米浆饮做好了。把它放进橱窗，客人才有机会看见。",
		"action_hint": "将米浆饮上架到橱窗。",
		"confirm_label": "去上架吧",
	},
	"rulebook": {
		"step_name": "查看规则",
		"dialogue": "商品已经进橱窗了。摆放位置会影响经营效果，先看看这里的构筑规则。",
		"action_hint": "打开“构筑规则”。",
		"confirm_label": "看看规则",
	},
	"arrange": {
		"step_name": "调整橱窗",
		"dialogue": "看懂规则后，亲手调整一次吧。把米浆饮拖到新位置，再旋转一次。",
		"action_hint": "拖动并右键旋转米浆饮各一次。",
		"confirm_label": "调整橱窗",
	},
	"business": {
		"step_name": "开始营业",
		"dialogue": "橱窗已经准备好了。现在开门营业，看看这套摆法能带来怎样的结果。",
		"action_hint": "点击“开始营业”。",
		"confirm_label": "开门营业",
	},
	"storefront": {
		"step_name": "查看经营",
		"dialogue": "第一轮营业开始了。去经营中心看看状态，学会关注客流和收益。",
		"action_hint": "打开“经营中心”。",
		"confirm_label": "看看经营状态",
	},
	"settlement": {
		"step_name": "完成真实结算",
		"dialogue": "营业已经开始了。等这一轮结束后完成结算，真正卖出至少一件商品，才算走完第一轮经营。",
		"action_hint": "等待营业结束并完成结算；本轮至少售出 1 件商品。",
		"confirm_label": "我会认真结算",
	},
	"complete": {
		"step_name": "外婆的最后叮嘱",
		"dialogue": "接下来就交给你啦。外婆不在的时候，可以查看‘任务’，帮助你更好地经营店铺哦。",
		"action_hint": "确认后开放任务，并将店铺提升到 Lv.1。",
		"confirm_label": "谢谢外婆",
	},
}


static func dialogue_for_step(step: String) -> Dictionary:
	return (DIALOGUES.get(step, FALLBACK) as Dictionary).duplicate(true)
