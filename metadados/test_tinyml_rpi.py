import cv2
import numpy as np
import tflite_runtime.interpreter as tflite
import time

# --- CONFIGURAÇÕES ---
model_path = "/home/maxwell/realwaste_mobilenetv2_quant.tflite"
label_list = ['Cardboard', 'Food Organics', 'Glass', 'Metal',
              'Miscellaneous Trash', 'Paper', 'Plastic', 'Textile Trash', 'Vegetation']

# --- CARREGAR MODELO ---
interpreter = tflite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# --- INICIALIZAR CÂMERA ---
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Erro ao abrir a câmera")
    exit()

# --- LOOP PRINCIPAL ---
try:
    # inicializa métricas de tempo
    ema_latency = None        # média exponencial da latência (ms)
    ema_alpha = 0.12          # fator da média exponencial (0-1)
    frame_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Erro ao capturar frame")
            break

        # Preparar frame para o modelo
        input_shape = input_details[0]['shape']  # [1, altura, largura, canais]
        h, w = input_shape[1], input_shape[2]
        img_model = cv2.resize(frame, (w, h))

        # Converter para uint8 se modelo quantizado
        input_data = np.expand_dims(img_model, axis=0).astype(np.uint8)

        # Inferência (medindo tempo)
        interpreter.set_tensor(input_details[0]['index'], input_data)
        t0 = time.perf_counter()
        interpreter.invoke()
        t1 = time.perf_counter()
        output_data = interpreter.get_tensor(output_details[0]['index'])[0]

        # latência da inferência em ms
        latency_ms = (t1 - t0) * 1000.0
        # atualizar média exponencial
        if ema_latency is None:
            ema_latency = latency_ms
        else:
            ema_latency = ema_alpha * latency_ms + (1.0 - ema_alpha) * ema_latency

        # Obter classe com maior probabilidade
        class_idx = np.argmax(output_data)
        confidence = output_data[class_idx] / 255.0  # como é quantizado uint8
        class_name = label_list[class_idx]

        # Escrever resultado no frame (inclui latência atual e média)
        text = f"{class_name}: {confidence*100:.1f}% | {latency_ms:.1f} ms (avg {ema_latency:.1f} ms)"
        cv2.putText(frame, text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # Mostrar frame
        cv2.imshow("Camera + TFLite", frame)

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
