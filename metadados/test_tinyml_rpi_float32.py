import cv2
import numpy as np
import tflite_runtime.interpreter as tflite
import time

# --- CONFIGURAÇÕES ---
# ATENÇÃO: Atualize o caminho para o seu modelo .tflite (versão float/float32)
model_path = "/home/maxwell/realwaste_mobilenetv2_float.tflite" 
label_list = ['Cardboard', 'Food Organics', 'Glass', 'Metal',
              'Miscellaneous Trash', 'Paper', 'Plastic', 'Textile Trash', 'Vegetation']

# --- CARREGAR MODELO ---
interpreter = tflite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Verificação opcional para garantir que o modelo é float32
if input_details[0]['dtype'] != np.float32:
    print("AVISO: O modelo carregado parece não esperar float32. Verifique se é o arquivo correto.")

# --- INICIALIZAR CÂMERA ---
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Erro ao abrir a câmera")
    exit()

# --- LOOP PRINCIPAL ---
try:
    # inicializa métricas de tempo
    ema_latency = None        
    ema_alpha = 0.12          
    frame_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Erro ao capturar frame")
            break

        # --- PRÉ-PROCESSAMENTO (ADAPTADO PARA FLOAT) ---
        input_shape = input_details[0]['shape'] 
        h, w = input_shape[1], input_shape[2]
        
        # 1. Redimensionar
        img_resized = cv2.resize(frame, (w, h))
        
        # 2. Converter para float32 e Normalizar
        # Modelos float geralmente esperam dados normalizados.
        # Opção A (Mais comum): Valores entre 0 e 1
        input_data = (img_resized.astype(np.float32) / 255.0)
        
        # Opção B (Comum em MobileNet original): Valores entre -1 e 1
        # Se a detecção estiver ruim com a Opção A, descomente a linha abaixo:
        # input_data = (img_resized.astype(np.float32) - 127.5) / 127.5

        # 3. Adicionar dimensão do batch (Batch dimension)
        input_data = np.expand_dims(input_data, axis=0)

        # --- INFERÊNCIA ---
        interpreter.set_tensor(input_details[0]['index'], input_data)
        t0 = time.perf_counter()
        interpreter.invoke()
        t1 = time.perf_counter()
        
        # --- PÓS-PROCESSAMENTO (ADAPTADO PARA FLOAT) ---
        output_data = interpreter.get_tensor(output_details[0]['index'])[0]

        # latência da inferência em ms
        latency_ms = (t1 - t0) * 1000.0
        
        # atualizar média exponencial (suavização do tempo)
        if ema_latency is None:
            ema_latency = latency_ms
        else:
            ema_latency = ema_alpha * latency_ms + (1.0 - ema_alpha) * ema_latency

        # Obter classe com maior probabilidade
        class_idx = np.argmax(output_data)
        
        # MUDANÇA AQUI: A saída já é float, não precisa dividir por 255
        confidence = output_data[class_idx] 
        class_name = label_list[class_idx]

        # Escrever resultado no frame
        text = f"{class_name}: {confidence*100:.1f}% | {latency_ms:.1f} ms (avg {ema_latency:.1f} ms)"
        cv2.putText(frame, text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # Mostrar frame
        cv2.imshow("Camera + TFLite (Float)", frame)

        # Sair se apertar 'q'
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        # log simples a cada 30 frames
        frame_count += 1
        if frame_count % 30 == 0:
            print(f"Inferência: {latency_ms:.1f} ms, EMA: {ema_latency:.1f} ms")

finally:
    cap.release()
    cv2.destroyAllWindows()