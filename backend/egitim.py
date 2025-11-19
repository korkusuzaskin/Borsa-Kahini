import os
import numpy as np
import yfinance as yf
from datetime import datetime
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout

# ==========================================
# 🚀 DEV VARLIK LİSTESİ (50 Kripto dahil)
# ==========================================
varliklar = [
    # --- KRİPTO PARALAR (Top 50) ---
    "BTC-USD", "ETH-USD", "BNB-USD", "SOL-USD", "XRP-USD", 
    "DOGE-USD", "ADA-USD", "AVAX-USD", "SHIB-USD", "DOT-USD",
    "MATIC-USD", "LTC-USD", "BCH-USD", "LINK-USD", "XLM-USD",
    "ETC-USD", "VET-USD", "TRX-USD", "FIL-USD", "ICP-USD",
    "THETA-USD", "FTM-USD", "MANA-USD", "SAND-USD", "GRT-USD",
    "AAVE-USD", "AXS-USD", "QNT-USD", "CHZ-USD", "ALGO-USD",
    "EOS-USD", "NEO-USD", "ZEC-USD", "DASH-USD", "XTZ-USD",
    "UNI3-USD", "AAVE3-USD", "ATOM-USD", "XMR-USD", "HBAR-USD",
    "EGLD-USD", "CRV-USD", "COMP-USD", "NEAR-USD", "APT-USD",
    "GALA-USD", "MKR-USD", "KAVA-USD", "FET-USD", "WAVES-USD", 
    "FLOKI-USD",     

    # --- DÖVİZLER (TL Karşılığı) ---
    "USDTRY=X", "EURTRY=X", "GBPTRY=X", "CHFTRY=X", "JPYTRY=X", 
    "CADTRY=X", "AUDTRY=X", "CNYTRY=X", "SARTRY=X", "RUBTRY=X",

    # --- EMTİALAR ---
    "GC=F",  # Altın (Ons)
    "SI=F",  # Gümüş
    "CL=F",  # Ham Petrol
    "PL=F",  # Platin
]

# Ayarlar
start_date = "2020-01-01"
time_step = 60 

print(f"🚀 Toplam {len(varliklar)} varlık için eğitim başlıyor... Bu işlem uzun sürebilir.")

for ticker in varliklar:
    safe_name = ticker
    model_name = f"{safe_name}_lite_model.keras"
    
    if os.path.exists(model_name):
        #print(f"✅ {ticker} zaten var, atlanıyor.")
        continue

    print(f"⏳ {ticker} eğitiliyor...")
    
    try:
        end_date = datetime.now().strftime('%Y-%m-%d')
        df = yf.download(ticker, start=start_date, end=end_date, progress=False)
        
        if len(df) < 100:
            print(f"❌ {ticker} verisi yetersiz.")
            continue

        df['MA50'] = df['Close'].rolling(window=50).mean()
        df.dropna(inplace=True)
        
        data = df[['Close', 'MA50']].values
        scaler = MinMaxScaler(feature_range=(0, 1))
        scaled_data = scaler.fit_transform(data)
        
        x_input, y_output = [], []
        for i in range(time_step, len(scaled_data)):
            x_input.append(scaled_data[i-time_step:i, :])
            y_output.append(scaled_data[i, 0])
            
        x_input, y_output = np.array(x_input), np.array(y_output)
        x_input = np.reshape(x_input, (x_input.shape[0], x_input.shape[1], x_input.shape[2]))

        model = Sequential()
        model.add(LSTM(32, return_sequences=False, input_shape=(x_input.shape[1], x_input.shape[2])))
        model.add(Dropout(0.1))
        model.add(Dense(1))
        model.compile(optimizer='adam', loss='mse')
        
        model.fit(x_input, y_output, epochs=5, batch_size=16, verbose=0)
        model.save(model_name)
        print(f"💾 {ticker} hazır!")
        
    except Exception as e:
        print(f"⚠️ {ticker} hatası: {e}")

print("🎉 TÜM MODELLER EĞİTİLDİ! GitHub'a yükle.")