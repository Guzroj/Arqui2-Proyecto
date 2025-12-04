# 🔧 CORRECCIÓN ARB_WRITE EN DSA_Memory_Adapter.sv

**Fecha:** Diciembre 3, 2025
**Archivo:** `rtl/DSA_Memory_Adapter.sv`

---

## 🎯 PROBLEMA IDENTIFICADO

### **Síntomas:**
```
PERF_READS:   4            (primeras 4 lecturas exitosas) ✅
PERF_WRITES:  0            (NUNCA escribe) ❌
PERF_CYCLES:  aumentando   (reloj funciona) ✅
busy = 1                   (bloqueado permanentemente)
done = 0                   (nunca termina)
```

### **Progreso observado:**
- Test: 4×4 → 2×2 (4 píxeles de salida)
- Lecturas esperadas: 16 (4 lecturas por píxel)
- **Lecturas reales: 4** (solo completó el primer píxel)
- **Escrituras reales: 0** (nunca escribió el resultado)

### **Diagnóstico:**
El sistema procesó correctamente las primeras 4 lecturas (I00, I10, I01, I11 del píxel 0), luego intentó escribir el resultado interpolado, pero **se bloqueó en el estado ARB_WRITE** esperando que `avm_waitrequest = 0`, condición que nunca se cumplió.

---

## 🔴 CAUSA RAÍZ

### **Código Original (INCORRECTO):**

```systemverilog
ARB_WRITE: begin
    if (!avm_waitrequest) begin  // ← PROBLEMA: Espera waitrequest=0 ANTES de emitir
        avm_write   <= 1'b1;
        avm_address <= output_base_addr + (word_addr << 2);
        // ... byteenable, writedata ...
        perf_mem_writes <= perf_mem_writes + 32'd1;
        state <= ARB_IDLE;
    end
end
```

### **Por qué fallaba:**

1. **Violación del protocolo Avalon-MM:**
   - El master debe emitir `avm_write = 1` **PRIMERO**
   - Luego el slave puede poner `waitrequest = 1` si está ocupado
   - El código original esperaba `waitrequest = 0` ANTES de emitir `avm_write`

2. **Deadlock:**
   - Si `waitrequest` no está en 0 por defecto (o tiene valor indefinido)
   - El `if (!avm_waitrequest)` nunca se cumple
   - Nunca se emite `avm_write = 1`
   - BRAM nunca sabe que hay un request de escritura
   - `waitrequest` nunca cambia
   - **Bloqueo infinito**

3. **Confirmación:**
   - `PERF_WRITES = 0` confirma que la línea `perf_mem_writes++` **NUNCA se ejecutó**
   - Por lo tanto, el `if` nunca fue verdadero
   - Por lo tanto, `avm_write` nunca se emitió

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **Patrón aplicado:**
La misma corrección que ya funcionó exitosamente en `ARB_READ`.

### **Cambios realizados:**

#### **1. Nuevas señales de control (líneas 108-112):**

```systemverilog
// Señales para trackear escritura y mantener datos
logic        write_issued;
logic [31:0] write_address_hold;
logic [31:0] write_data_hold;
logic [3:0]  write_byteenable_hold;
```

**Propósito:**
- `write_issued`: Indica si ya emitimos la escritura (evita emitir múltiples veces)
- `write_address_hold`: Guarda la dirección mientras esperamos confirmación
- `write_data_hold`: Guarda los datos a escribir
- `write_byteenable_hold`: Guarda el byte enable

---

#### **2. Reset de señales (líneas 201-204):**

```systemverilog
write_issued     <= 1'b0;
write_address_hold <= 32'd0;
write_data_hold  <= 32'd0;
write_byteenable_hold <= 4'b0000;
```

---

#### **3. Modificación de defaults (línea 221-222):**

**Antes:**
```systemverilog
avm_write <= 1'b0;  // Se ejecutaba cada ciclo
```

**Después:**
```systemverilog
// NOTA: avm_read y avm_write se manejan específicamente en cada estado
// No los ponemos en 0 por defecto para mantenerlos activos si es necesario
```

**Razón:** Permitir que `avm_write` se mantenga activo mientras esperamos `waitrequest = 0`.

---

#### **4. Estado ARB_IDLE actualizado (líneas 229-242):**

```systemverilog
ARB_IDLE: begin
    avm_read  <= 1'b0;
    avm_write <= 1'b0;  // ← Agregado
    read_issued  <= 1'b0;
    write_issued <= 1'b0;  // ← Agregado

    if (write_req) begin
        state <= ARB_WRITE;
        write_issued <= 1'b0;  // ← Resetear flag al entrar
    end else if (read_req) begin
        state <= ARB_READ;
        read_issued <= 1'b0;
    end
end
```

---

#### **5. Estado ARB_WRITE COMPLETAMENTE REESCRITO (líneas 248-305):**

### **Nueva lógica - Fase 1: Emitir escritura (una sola vez)**

```systemverilog
ARB_WRITE: begin
    if (!write_issued) begin
        // Calcular dirección word y byte offset
        logic [31:0] word_addr;
        logic [1:0]  byte_offs;

        word_addr = write_addr >> 2;
        byte_offs = write_addr[1:0];

        // Calcular y guardar dirección
        write_address_hold <= output_base_addr + (word_addr << 2);

        // Calcular y guardar writedata y byteenable según offset
        case (byte_offs)
            2'b00: begin
                write_byteenable_hold <= 4'b0001;
                write_data_hold       <= {24'd0, write_data};
            end
            2'b01: begin
                write_byteenable_hold <= 4'b0010;
                write_data_hold       <= {16'd0, write_data, 8'd0};
            end
            2'b10: begin
                write_byteenable_hold <= 4'b0100;
                write_data_hold       <= {8'd0, write_data, 16'd0};
            end
            2'b11: begin
                write_byteenable_hold <= 4'b1000;
                write_data_hold       <= {write_data, 24'd0};
            end
        endcase

        // Emitir escritura Avalon-MM inmediatamente
        avm_write      <= 1'b1;
        avm_address    <= output_base_addr + (word_addr << 2);
        avm_writedata  <= write_data_hold;
        avm_byteenable <= write_byteenable_hold;
        write_issued   <= 1'b1;
        perf_mem_writes <= perf_mem_writes + 32'd1;  // ✅ Incrementa inmediatamente
    end
```

**Cambios clave:**
- ✅ Emite `avm_write = 1` **inmediatamente** al entrar al estado
- ✅ **NO requiere** que `waitrequest = 0` para emitir
- ✅ Incrementa `perf_mem_writes` inmediatamente (confirma que se emitió)
- ✅ Guarda dirección, datos y byteenable para mantenerlos estables

---

### **Fase 2: Mantener señales activas**

```systemverilog
    end else begin
        // Mantener señales activas según protocolo Avalon-MM
        if (avm_waitrequest) begin
            // Memoria ocupada: mantener señales activas
            avm_write      <= 1'b1;
            avm_address    <= write_address_hold;
            avm_writedata  <= write_data_hold;
            avm_byteenable <= write_byteenable_hold;
        end else begin
            // waitrequest=0: transacción aceptada, bajar write y volver a IDLE
            avm_write      <= 1'b0;
            write_issued   <= 1'b0;
            state          <= ARB_IDLE;
        end
    end
end
```

**Cambios clave:**
- ✅ Mantiene `avm_write = 1` mientras `waitrequest = 1` (protocolo Avalon-MM correcto)
- ✅ Baja `avm_write = 0` cuando `waitrequest = 0` (transacción aceptada)
- ✅ Vuelve a `ARB_IDLE` solo después de que la escritura fue aceptada
- ✅ Usa señales `_hold` para mantener valores estables

---

## 📋 FLUJO CORREGIDO

### **Secuencia Esperada:**

```
Ciclo N:   Downscale emite out_mem_we = 1 (escritura del píxel 0)
           └─> write_req = 1 (combinacional)
           └─> FSM: ARB_IDLE → ARB_WRITE ✓

Ciclo N+1: Estado ARB_WRITE
           ├─ write_issued = 0 → Emite avm_write = 1 ✓
           ├─ avm_address = output_base + (word_addr << 2) ✓
           ├─ avm_writedata = datos formateados ✓
           ├─ avm_byteenable = byte enable correcto ✓
           ├─ perf_mem_writes++ ✓
           └─ write_issued = 1

Ciclo N+2: Estado ARB_WRITE (write_issued = 1)
           ├─ Si waitrequest = 1:
           │   └─> Mantiene avm_write = 1, address, data, byteenable
           └─ Si waitrequest = 0:
               ├─> Baja avm_write = 0
               ├─> write_issued = 0
               └─> state = ARB_IDLE

Ciclo N+3: Estado ARB_IDLE
           └─> Listo para procesar siguiente request (lectura o escritura)
```

---

## 🎯 RESULTADO ESPERADO

1. ✅ `avm_write` se emite inmediatamente al entrar a ARB_WRITE
2. ✅ `perf_mem_writes` incrementa (ya no será 0)
3. ✅ `avm_write` se mantiene activo mientras waitrequest = 1
4. ✅ OUTPUT_BRAM recibe el request y acepta la escritura (waitrequest = 0)
5. ✅ FSM vuelve a ARB_IDLE y puede continuar procesando
6. ✅ Siguientes lecturas (píxel 1, 2, 3...) se procesan correctamente
7. ✅ `busy` finalmente termina cuando `done` se activa

---

## 📊 COMPARACIÓN: ARB_READ vs ARB_WRITE

Ambos estados ahora siguen el **mismo patrón** de 3 fases:

| Fase | ARB_READ | ARB_WRITE |
|------|----------|-----------|
| **1. Emitir** | `avm_read = 1` inmediatamente | `avm_write = 1` inmediatamente |
| **2. Mantener** | Mientras `waitrequest = 1` | Mientras `waitrequest = 1` |
| **3. Completar** | Esperar `readdatavalid = 1` | Esperar `waitrequest = 0` |

**Diferencia clave:**
- **Lecturas:** Tienen señal adicional `readdatavalid` (datos llegan después)
- **Escrituras:** Se consideran completas cuando `waitrequest = 0` (fire-and-forget)

---

## ⚠️ NOTAS IMPORTANTES

### **1. Protocolo Avalon-MM para escrituras:**
- Master debe emitir `write = 1` con `address`, `writedata`, `byteenable`
- Si slave está ocupado, pone `waitrequest = 1`
- Master debe **mantener todas las señales estables** mientras `waitrequest = 1`
- Cuando `waitrequest = 0`, la transacción fue aceptada
- **NO hay señal de confirmación adicional** (a diferencia de lecturas)

### **2. Diferencia con lecturas:**
- **Lecturas:** 2 fases (emisión + espera de `readdatavalid`)
- **Escrituras:** 1 fase (emisión + espera de `waitrequest = 0`)

### **3. Sincronización:**
- `write_req` es combinacional (cambia inmediatamente)
- `write_addr` y `write_data` pueden cambiar, por eso guardamos en `_hold`
- Usar señales `_hold` asegura estabilidad durante la transacción

---

## 🔄 PRÓXIMOS PASOS

1. ✅ **Compilar el diseño** en Quartus
2. ✅ **Regenerar HDL** en Platform Designer (si es necesario)
3. ✅ **Reprogramar FPGA** con el nuevo bitstream
4. ✅ **Ejecutar test:** `test_downscale_quick` (4×4 → 2×2)
5. ✅ **Verificar resultados:**
   - `PERF_READS` debe llegar a 16 (4 píxeles × 4 lecturas)
   - `PERF_WRITES` debe llegar a 4 (4 píxeles de salida)
   - `busy` debe terminar (pasar a 0)
   - `done` debe activarse (pasar a 1)

---

## 📝 ARCHIVOS MODIFICADOS

- **`rtl/DSA_Memory_Adapter.sv`**
  - Líneas agregadas: 108-112 (señales nuevas)
  - Líneas modificadas: 201-204 (reset), 215-222 (defaults), 229-242 (IDLE), 248-305 (ARB_WRITE)
  - **Total cambios:** ~80 líneas modificadas/agregadas

---

## ✅ VERIFICACIÓN POST-COMPILACIÓN

Después de compilar y programar, verificar:

```tcl
% test_downscale_quick

# Debería ver:
PERF_READS:   16   (completó todas las lecturas) ✅
PERF_WRITES:  4    (completó todas las escrituras) ✅
busy:         0    (terminó correctamente) ✅
done:         1    (señal de finalización activa) ✅
```

Si ves estos valores, **la corrección funcionó correctamente**. 🎉

---

**Autor:** Claude (Anthropic)
**Colaboración:** Usuario (Gabriel)
**Proyecto:** DSA Downscaler - Intel Cyclone V FPGA
