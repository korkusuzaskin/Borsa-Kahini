import os
import numpy as np
import yfinance as yf
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Security, Depends
from fastapi.security.api_key import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense, Dropout

app = FastAPI()

# --- GÜVENLİK VE CORS ---
# Kendi Netlify adresini buraya ekleyebilirsin
IZINLI_SITELER = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=IZINLI_SITELER,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = "BorsaKahini_GizliSifre_2025"
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=True)


async def get_api_key(api_key_header: str = Security(api_key_header)):
    if api_key_header == API_KEY:
        return api_key_header
    else:
        raise HTTPException(status_code=403, detail="⛔ Yetkisiz Erişim")


# --- HAFIZA ---
SONUC_HAFIZASI = {}
HAFIZA_SURESI_DAKIKA = 60

# --- AYARLAR ---
start_date = "2020-01-01"
time_step = 30
ESIK_DEGERI = 0.005


class HisseIstegi(BaseModel):
    sembol: str


def analiz_et(ticker):
    global SONUC_HAFIZASI

    if "." in ticker and "USD" in ticker:
        ticker = ticker.replace(".", "-")

    # 1. HAFIZA KONTROLÜ
    if ticker in SONUC_HAFIZASI:
        kayit = SONUC_HAFIZASI[ticker]
        if datetime.now() - kayit["zaman"] < timedelta(minutes=HAFIZA_SURESI_DAKIKA):
            print(f"🚀 Hafızadan: {ticker}")
            return kayit["veri"]

    try:
        # 2. VERİ İNDİRME
        bugun = datetime.now().strftime('%Y-%m-%d')
        df = yf.download(ticker, start=start_date, end=bugun, progress=False)

        if len(df) < 100: return None

        # İndikatörler
        df['MA50'] = df['Close'].rolling(window=50).mean()
        df.dropna(inplace=True)

        # --- YENİ: GRAFİK İÇİN SON 30 GÜN VERİSİ ---
        # Son 30 günün kapanış fiyatlarını listeye çeviriyoruz
        son_30_gun = df['Close'].tail(30).values.flatten().tolist()
        # -------------------------------------------

        # Veri Hazırlama
        data = df[['Close', 'MA50']].values
        scaler = MinMaxScaler(feature_range=(0, 1))
        scaled_data = scaler.fit_transform(data)

        scaler_target = MinMaxScaler(feature_range=(0, 1))
        scaler_target.fit(df[['Close']])

        x_input, y_output = [], []
        for i in range(time_step, len(scaled_data)):
            x_input.append(scaled_data[i - time_step:i, :])
            y_output.append(scaled_data[i, 0])

        x_input, y_output = np.array(x_input), np.array(y_output)
        x_input = np.reshape(x_input, (x_input.shape[0], x_input.shape[1], x_input.shape[2]))

        # 3. MODEL (LITE)
        model_name = f"{ticker}_lite_model.keras"
        if os.path.exists(model_name):
            model = load_model(model_name)
        else:
            model = Sequential()
            model.add(LSTM(32, return_sequences=False, input_shape=(x_input.shape[1], x_input.shape[2])))
            model.add(Dropout(0.1))
            model.add(Dense(1))
            model.compile(optimizer='adam', loss='mse')
            model.fit(x_input, y_output, epochs=5, batch_size=16, verbose=0)
            model.save(model_name)

        # 4. TAHMİN
        last_block = scaled_data[-time_step:, :]
        x_future = np.reshape(last_block, (1, time_step, scaled_data.shape[1]))
        pred_scaled = model.predict(x_future, verbose=0)
        tahmin = float(scaler_target.inverse_transform(pred_scaled)[0, 0])
        fiyat = float(df['Close'].values.flatten()[-1])

        if tahmin > fiyat * (1 + ESIK_DEGERI):
            sinyal = "AL 🟢"
        elif tahmin < fiyat:
            sinyal = "SAT 🔴"
        else:
            sinyal = "BEKLE ⚪"

        sonuc_objesi = {
            "hisse": ticker,
            "fiyat": round(fiyat, 2),
            "tahmin": round(tahmin, 2),
            "fark": round(((tahmin - fiyat) / fiyat) * 100, 2),
            "sinyal": sinyal,
            "gecmis": son_30_gun  # <-- Grafik verisi buraya eklendi
        }

        SONUC_HAFIZASI[ticker] = {"zaman": datetime.now(), "veri": sonuc_objesi}
        return sonuc_objesi

    except Exception as e:
        print(f"Hata: {e}")
        return None


@app.post("/analiz")
def api_analiz(istek: HisseIstegi, api_key: str = Depends(get_api_key)):
    sonuc = analiz_et(istek.sembol)
    if sonuc: return sonuc
    raise HTTPException(status_code=404, detail="Analiz başarısız")


@app.get("/")
def ana_sayfa():
    return {"mesaj": "Yapay Zeka Sunucusu Aktif 🚀"}
