import os
import numpy as np
from tensorflow.keras.preprocessing.image import ImageDataGenerator, img_to_array, load_img

# --- CONFIGURAÇÕES ---
input_dataset = "/content/drive/MyDrive/MeuTCC2/dataset/realwaste-main/RealWaste"
output_dataset = "/content/drive/MyDrive/MeuTCC2/dataset/realwaste-main/RW+"
target_size = (224, 224)            # tamanho que o modelo espera
default_target_per_class = 523      # meta de imagens por classe
augmentations_per_image = 10        # máximo de variações geradas por imagem

# Lista das classes (subpastas)
classes = ['Cardboard', 'Food Organics', 'Glass', 'Metal',
           'Miscellaneous Trash', 'Paper', 'Plastic', 'Textile Trash', 'Vegetation']

# --- CONFIGURAÇÃO DE DATA AUGMENTATION ---
datagen = ImageDataGenerator(
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.15,
    zoom_range=0.15,
    horizontal_flip=True,
    brightness_range=[0.7,1.3]
)

# Criar pasta de saída
os.makedirs(output_dataset, exist_ok=True)
for c in classes:
    os.makedirs(os.path.join(output_dataset, c), exist_ok=True)

# --- CONTAR IMAGENS POR CLASSE ---
class_counts = {}
for c in classes:
    class_path = os.path.join(input_dataset, c)
    imgs = [f for f in os.listdir(class_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    class_counts[c] = len(imgs)

# Meta final por classe: a maior entre a classe mais populosa e default_target_per_class
max_count = max(max(class_counts.values()), default_target_per_class)
print("Contagem original por classe:", class_counts)
print("Meta de imagens por classe:", max_count)

# --- GERAR DATA AUGMENTATION ---
for c in classes:
    class_path = os.path.join(input_dataset, c)
    output_class_path = os.path.join(output_dataset, c)
    imgs = [f for f in os.listdir(class_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

    current_count = len(imgs)
    needed = max_count - current_count
    print(f"Classe {c}: {current_count} originais, precisa gerar {needed}")

    # Salvar imagens originais
    for img_name in imgs:
        img = load_img(os.path.join(class_path, img_name), target_size=target_size)
        img.save(os.path.join(output_class_path, img_name))

    # Gerar imagens faltantes com data augmentation
    i_generated = 0
    img_idx = 0
    while i_generated < needed:
        img_name = imgs[img_idx % len(imgs)]
        img = load_img(os.path.join(class_path, img_name), target_size=target_size)
        x = img_to_array(img)
        x = np.expand_dims(x, axis=0)

        # Gerar até 'augmentations_per_image' variações
        for batch in datagen.flow(x, batch_size=1, save_to_dir=output_class_path,
                                  save_prefix='aug', save_format='jpg'):
            i_generated += 1
            if i_generated >= needed:
                break
        img_idx += 1

print("Dataset balanceado gerado em:", output_dataset)
