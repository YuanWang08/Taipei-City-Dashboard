import { ref, watch } from 'vue'
import { defineStore } from 'pinia'
import http from "../router/axios";

export const useChatStore = defineStore('chat', () => {
  	// 預設訊息
  	const defaultChatData = [
    	{
      		id: 1,
      		role: 'bot',
	  		isDefault: true,
      		content:
        	'您好，我是「雙北永續助手」🌱\n\n• 找電動車充電樁、推薦環保餐廳\n• 規劃散步降溫路線、餐後綠蔭步道\n• 估算行程碳排放\n\n試試問：\n💬「假日下午我帶老婆小孩在大安區附近活動，要充電 + 吃環保餐廳 + 餐後散步」\n💬「我從信義區開電動車到淡水，中間想充電兼吃飯」\n💬「夏天午後想找有遮蔭的散步路線」',
    	},
  	];

	// 雙北永續資料 (預先聚合的行政區統計)
	const SUSTAINABILITY_SYSTEM_PROMPT = `你是「雙北永續助手」，幫使用者規劃低碳生活：找電動車充電樁、推薦環保餐廳、規劃散步降溫路線、估算碳排放。情境包括日常通勤、家庭出遊、約會行程。

【雙北資料 (2025)】
各行政區資源 (汽車充電 / 機車充電 / 環保餐廳 數量)：
台北市：信義區(30/70/58) 大安區(22/60/97) 中山區(30/70/53) 內湖區(29/89/38) 北投區(22/84/31) 士林區(26/72/36) 文山區(16/78/23) 松山區(13/47/38) 中正區(12/37/47) 大同區(12/54/15) 萬華區(9/58/24) 南港區(13/53/19)
新北市：板橋區(17/66/147) 中和區(13/30/116) 新莊區(8/49/84) 三重區(15/49/61) 永和區(5/19/39) 新店區(10/28/37) 樹林區(0/24/28) 土城區(6/19/28) 淡水區(3/26/27) 林口區(3/22/27) 蘆洲區(5/15/29) 三峽區(3/22/17) 汐止區(1/20/20)

【用電結構 2025】
台北：服務業 54.35% / 住宅 34.20% / 工業 3.10%（商業大城）
新北：住宅 42.52% / 服務業 28.64% / 工業 25.76%（住商工平衡）

【碳排係數】
油車 0.21 kg CO2/km、電車 0.08、油機車 0.06、電機車 0.02

【散步降溫地點推薦能力】
- 台北綠地：大安森林公園、中正紀念堂、青年公園、士林官邸、北投公園、二二八和平紀念公園、富錦街林蔭大道、信義商圈步行區
- 河濱步道：大佳河濱、迎風河濱、古亭河濱、關渡自然公園、淡水河左岸、新店溪
- 新北綠地：板橋林家花園、新店碧潭、淡水河岸老街、新北大都會公園、永和仁愛公園、中和錦和運動公園、烏來瀑布步道
- 推薦時考慮季節（夏天優先有遮蔭的林蔭路）

【回答原則】
- 簡潔自然，避免用 [方括號] 標題格式
- 推薦時用「行政區+資源數量」當依據
- 行程要有時間配置（充電 30 分、用餐 1 小時、散步 1 小時 等）
- 一定算碳排比較給具體公斤數
- 不知道的事不要瞎掰，只用上面提到的地點`;

	const recommendComponents = ref(null)

  	// 從 sessionStorage 讀取
  	const savedChatData = JSON.parse(sessionStorage.getItem('chatData')) || [];

  	// 拼接預設訊息 + sessionStorage 的聊天紀錄
  	const chatData = ref([...defaultChatData, ...savedChatData]);

  	// 監聽 chatData 的變化，自動同步到 sessionStorage
  	watch(
    	chatData,
    	(newVal) => {
      	// 只存使用者與機器人的聊天訊息，不存重複的預設訊息
      	const userBotMessages = newVal.filter((item) => !item.isDefault)
      	sessionStorage.setItem('chatData', JSON.stringify(userBotMessages))
    	},
    	{ deep: true }
  	);

  	const addChatData = (newChatData) => {
    	chatData.value.push({ id: chatData.value.length + 1, isDefault: false, ...newChatData });
  	};

  	const addQueryData = async (newChatData) => {

    	chatData.value.push({ id: chatData.value.length + 1, isDefault: false, ...newChatData });

		recommendComponents.value = [];
		let topK = null;

		try {
			const response = await http.post(
  				"/vector/component",
  				new URLSearchParams({
    				query: newChatData.content,
    				limit: 10,
    				score: 0.8,
  				}),
  				{
    				headers: {
      					"Content-Type": "application/x-www-form-urlencoded",
    				},
  				}
			);
			if (response.data?.data?.length > 0) {
				recommendComponents.value = response.data.data;
			}

			// 去除重複項目存到 result
			const result = Array.from(
  				recommendComponents.value.reduce((map, item) => {
    				const key = item.index
    				const exist = map.get(key)

    				// 如果還沒放過，直接放
    				if (!exist) {
      					map.set(key, item)
      					return map
    				}

    				// 如果已存在，但現在的是 metrotaipei，就覆蓋
    				if (item.city === 'metrotaipei') {
      					map.set(key, item)
    				}

    				return map
  				}, new Map()).values()
			)
			// 把 result 蓋回去 recommendComponents
			recommendComponents.value = result

		} catch (error) { 
			console.error("VectorAnalysisError :", error);
		}

		if (recommendComponents.value && recommendComponents.value?.length > 0) {
			topK = [...recommendComponents.value].sort((a, b) => b.score - a.score);
			chatData.value.push({ id: chatData.value.length + 1, role: 'bot', isDefault: false, button: [{ id:1, text:'建立儀表板' }], content: `您好 😊 \n 以下是根據您的問題，自動為您推薦的「組件清單」。您可以將這些組件整批加入「個人儀表板」，方便日後快速查看與使用。\n`, relations: topK });
			chatData.value.push({ id: chatData.value.length + 1, role: 'bot', isDefault: false, content: `若您有任何新的查詢或想深入探索的內容，都可以隨時在對話框告訴我～\n 我很樂意再協助您 💬✨` });
		} else {
			chatData.value.push({ id: chatData.value.length + 1, role: 'bot', isDefault: false, content: `很抱歉，您提供的描述沒有相似組件，請繼續提問 ! ` });
		}

		// 分析結束後紀錄問答log
		saveChatLog(newChatData.content, recommendComponents.value);
  	};

	// 雙北永續助手對話：呼叫 TWCC LLM
	const askSustainabilityAI = async (newChatData) => {
		// 先加 user message
		chatData.value.push({ id: chatData.value.length + 1, isDefault: false, ...newChatData });
		// 加「思考中」placeholder
		const placeholderId = chatData.value.length + 1;
		chatData.value.push({ id: placeholderId, role: 'bot', isDefault: false, content: '思考中... 🌱', isLoading: true });

		try {
			// 組 messages：歷史對話 (排除 default + loading) + system + 新 user
			const history = chatData.value
				.filter(m => !m.isDefault && !m.isLoading && m.id !== placeholderId)
				.slice(-6) // 最近 6 則 keep context 短
				.map(m => ({
					role: m.role === 'bot' ? 'assistant' : 'user',
					content: m.content
				}));

			const response = await http.post('/ai/chat/twai', {
				messages: [
					{ role: 'system', content: SUSTAINABILITY_SYSTEM_PROMPT },
					...history,
				],
			});

			// 取出 LLM 回答
			const answer = response.data?.data?.content || '抱歉，沒拿到回答。';

			// 替換 loading message
			const idx = chatData.value.findIndex(m => m.id === placeholderId);
			if (idx >= 0) {
				chatData.value[idx] = { id: placeholderId, role: 'bot', isDefault: false, content: answer };
			}

			// 紀錄 chatlog（不擋）
			saveChatLog(newChatData.content, answer).catch(() => {});
		} catch (error) {
			console.error('SustainabilityAIError:', error);
			const idx = chatData.value.findIndex(m => m.id === placeholderId);
			const errMsg = error.response?.data?.message || error.message || '網路錯誤';
			if (idx >= 0) {
				chatData.value[idx] = { id: placeholderId, role: 'bot', isDefault: false, content: `❌ 出錯了：${errMsg}` };
			}
		}
	};

	const saveChatLog = async(question, answer) => {
		try {
        	const formData = new FormData();
        	const d = new Date();
        	const todayId =
          		d.getFullYear() +
          		String(d.getMonth() + 1).padStart(2, "0") +
          		String(d.getDate()).padStart(2, "0");

        	formData.append("session", "session_" + todayId);
        	formData.append("question", question);
        	formData.append("answer", JSON.stringify(answer));

        	await http.post("/chatlog/", formData, {
          		headers: {
            		"Content-Type": "multipart/form-data",
          		},
        	});
      	} catch (error) {
        	console.error("saveChatLog error:", error);
      	}
	};

	return { chatData, addChatData, addQueryData, askSustainabilityAI, saveChatLog }
})
