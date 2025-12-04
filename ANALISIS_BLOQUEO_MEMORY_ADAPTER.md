# 🔍 ANÁLISIS DETALLADO DEL BLOQUEO EN DSA_Memory_Adapter

## 📊 DATOS DEL DIAGNÓSTICO

```
PERF_CYCLES:  Aumentando normalmente (~50 MHz)
PERF_READS:   0 (NUNCA incrementa) ❌
PERF_WRITES:  0 (NUNCA incrementa) ❌
busy:         1 (permanente)
done:         0 (nunca se activa)
```

## 🎯 CONCLUSIÓN

**El sistema está bloqueado en el estado ARB_READ del DSA_Memory_Adapter esperando `avm_readdatavalid` que nunca llega.**

---

## 🔬 ANÁLISIS DEL ESTADO ARB_READ

### Código Actual (Líneas 265-287)

```systemverilog
ARB_READ: begin
    if (!avm_waitrequest && !avm_read) begin
        // Emitir lectura Avalon-MM
        avm_read        <= 1'b1;
        avm_address     <= input_base_addr + (word_address << 2);
        avm_byteenable  <= 4'b1111;
        perf_mem_reads  <= perf_mem_reads + 32'd1;
    end

    // Esperar readdatavalid
    if (avm_readdatavalid) begin
        if (is_simd_read) begin
            simd_mem_rd_valid[read_lane_idx] <= 1'b1;
            simd_mem_rd_data[read_lane_idx]  <= extracted_byte;
            rr_counter <= rr_counter + 3'd1;
        end else begin
            seq_mem_rd_valid <= 1'b1;
            seq_mem_rd_data  <= extracted_byte;
        }

        state <= ARB_IDLE;
    end
end
```

### 🔴 PROBLEMA 1: Lógica de Emisión de `avm_read`

**Condición para emitir lectura:**
```systemverilog
if (!avm_waitrequest && !avm_read) begin
    avm_read <= 1'b1;
    ...
end
```

**Problema identificado:**

Los **defaults** en línea 200 ponen `avm_read <= 1'b0` **CADA CICLO**:

```systemverilog
// Defaults (línea 199-201)
avm_read  <= 1'b0;  // ← Se ejecuta SIEMPRE primero
avm_write <= 1'b0;
```

**Flujo problemático:**

```
Ciclo N:   Entra a ARB_READ
           ├─ Defaults: avm_read <= 1'b0
           └─ if (!avm_waitrequest && !avm_read) → Si waitrequest=0, emite avm_read=1

Ciclo N+1: Sigue en ARB_READ
           ├─ Defaults: avm_read <= 1'b0  ← ⚠️ PROBLEMA: Lo vuelve a poner en 0
           ├─ if (!avm_waitrequest && !avm_read) → Verifica otra vez
           └─ Si waitrequest=1, NO emite lectura
           
           └─ Espera readdatavalid (que nunca llega)
```

**Resultado:** `avm_read` se emite en el ciclo N, pero en el ciclo N+1 los defaults lo ponen en 0 de nuevo, y si `avm_waitrequest` está activo, nunca se vuelve a emitir.

---

### 🔴 PROBLEMA 2: PERF_READS = 0 Confirma que `avm_read` NUNCA se emitió

**Lógica del contador (línea 271):**
```systemverilog
perf_mem_reads <= perf_mem_reads + 32'd1;  // Solo dentro del if
```

**Si PERF_READS = 0, significa que:**
- El `if (!avm_waitrequest && !avm_read)` **NUNCA** se cumplió
- Por lo tanto, `avm_read` **NUNCA** se emitió
- Por lo tanto, la lectura **NUNCA** se inició

**Posibles causas:**

1. **`avm_waitrequest` está SIEMPRE en 1** (memoria ocupada)
2. **La condición nunca se evalúa como verdadera**
3. **El estado ARB_READ nunca se alcanza**

---

### 🔴 PROBLEMA 3: Señal `avm_read` no se mantiene

**En Avalon-MM estándar:**
- `avm_read` debe mantenerse en 1 hasta que `avm_waitrequest` baje a 0
- El master debe mantener `avm_read = 1` mientras espera la respuesta

**Problema actual:**
```systemverilog
// Defaults (cada ciclo)
avm_read <= 1'b0;  // ← Lo pone en 0 cada ciclo

// En ARB_READ
if (!avm_waitrequest && !avm_read) begin  // Solo emite si waitrequest=0
    avm_read <= 1'b1;
end
```

**Si `avm_waitrequest = 1`:**
- El `if` nunca se ejecuta
- `avm_read` se mantiene en 0 (por defaults)
- La lectura nunca se emite
- El estado queda bloqueado esperando algo que nunca ocurrirá

---

## 🔬 ANÁLISIS DEL FLUJO COMPLETO

### Secuencia Esperada (correcta):

```
1. Downscale_Secuencial emite:
   └─ mem_rd_req = 1
   └─ mem_rd_addr = 0x00000000 (dirección del primer píxel)

2. DSA_Memory_Adapter - Arbitraje:
   └─ read_req = seq_mem_rd_req = 1
   └─ read_addr = seq_mem_rd_addr = 0x00000000
   └─ word_address = 0x00000000 >> 2 = 0x00000000

3. FSM cambia a ARB_READ:
   └─ state <= ARB_READ

4. En ARB_READ (primer ciclo):
   └─ Defaults: avm_read <= 0
   └─ Si waitrequest = 0:
      └─ avm_read <= 1
      └─ avm_address <= input_base + (0 << 2) = 0x00000000
      └─ perf_mem_reads++

5. BRAM responde:
   └─ avm_waitrequest = 0 (o 1 si ocupada)
   └─ avm_readdatavalid = 1 (después de latencia)
   └─ avm_readdata = datos

6. DSA_Memory_Adapter recibe respuesta:
   └─ Si readdatavalid = 1:
      └─ seq_mem_rd_valid <= 1
      └─ seq_mem_rd_data <= byte extraído
      └─ state <= ARB_IDLE
```

### Secuencia Actual (bloqueada):

```
1. Downscale_Secuencial emite:
   └─ mem_rd_req = 1 ✓
   └─ mem_rd_addr = 0x00000000 ✓

2. DSA_Memory_Adapter - Arbitraje:
   └─ read_req = 1 ✓
   └─ read_addr = 0x00000000 ✓

3. FSM cambia a ARB_READ:
   └─ state <= ARB_READ ✓

4. En ARB_READ:
   └─ Defaults: avm_read <= 0
   └─ Si waitrequest = 1:  ← ❌ PROBLEMA AQUÍ
      └─ El if NO se ejecuta
      └─ avm_read se queda en 0
      └─ perf_mem_reads NO incrementa

5. BRAM nunca recibe request:
   └─ avm_read nunca fue 1
   └─ BRAM no responde

6. Estado bloqueado:
   └─ ARB_READ espera readdatavalid (que nunca llega)
   └─ PERF_READS = 0 confirma que nunca se emitió lectura
```

---

## 🎯 CAUSAS RAÍZ IDENTIFICADAS

### Causa 1: Lógica de Emisión de Lectura Incorrecta

**Problema:**
- La condición `!avm_waitrequest && !avm_read` requiere que waitrequest sea 0
- Si waitrequest está en 1, nunca emite la lectura
- Pero waitrequest podría estar en 1 porque no se ha emitido ninguna lectura

**Ciclo vicioso:**
```
waitrequest = 1 → No emite avm_read → BRAM no sabe que hay request → waitrequest sigue en 1
```

### Causa 2: Señal `avm_read` no se mantiene

**Problema:**
- Los defaults ponen `avm_read = 0` cada ciclo
- En Avalon-MM, si waitrequest = 1, el master debe mantener `read = 1` hasta que waitrequest baje
- El código actual no mantiene `avm_read` activo mientras espera

### Causa 3: No hay lógica de retry o timeout

**Problema:**
- Si waitrequest está permanentemente en 1, el estado queda bloqueado para siempre
- No hay mecanismo de timeout o retry
- No hay forma de salir del estado ARB_READ

---

## 📋 VERIFICACIONES NECESARIAS

### 1. ¿`avm_waitrequest` está siempre en 1?

**Verificación:** Revisar la configuración del BRAM en Qsys:
- Latencia de lectura configurada
- Si waitrequest está habilitado
- Si hay conflictos de acceso

### 2. ¿El estado ARB_READ se alcanza?

**Verificación:** Verificar que:
- `read_req` se activa cuando hay `seq_mem_rd_req`
- La FSM transiciona de ARB_IDLE a ARB_READ

### 3. ¿La dirección es correcta?

**Verificación:** Verificar que:
- `input_base_addr` es correcto (0x00000000)
- `word_address` se calcula correctamente
- La dirección final está en rango del BRAM

---

## 🔧 PROBLEMAS ESPECÍFICOS EN EL CÓDIGO

### Problema A: Condición de emisión de lectura

**Línea 266:**
```systemverilog
if (!avm_waitrequest && !avm_read) begin
```

**Problemas:**
1. Requiere que waitrequest sea 0, pero podría estar en 1
2. No mantiene `avm_read` activo mientras espera respuesta
3. Si waitrequest nunca baja, nunca emite la lectura

### Problema B: Defaults que resetean señales

**Línea 200:**
```systemverilog
avm_read <= 1'b0;  // Default cada ciclo
```

**Problema:**
- Resetea `avm_read` cada ciclo, incluso si debe mantenerse activo
- En Avalon-MM, si waitrequest = 1, el master debe mantener read = 1

### Problema C: No hay lógica para mantener `avm_read` activo

**Falta:**
- Lógica para mantener `avm_read = 1` mientras waitrequest = 1
- Solo emite read una vez, pero si waitrequest está activo, debería mantenerlo

---

## 🎯 DIAGNÓSTICO FINAL

**PERF_READS = 0** significa que la línea 271 **NUNCA** se ejecutó, lo que significa que:

1. ✅ El estado ARB_READ SÍ se alcanza (de otra forma busy no estaría activo)
2. ❌ La condición `!avm_waitrequest && !avm_read` NUNCA es verdadera
3. ❌ Por lo tanto, `avm_waitrequest` está SIEMPRE en 1, O
4. ❌ Hay un problema con la lógica que impide que se cumpla la condición

**Causa más probable:**
- `avm_waitrequest` está siempre en 1
- Esto impide que se emita `avm_read`
- Sin `avm_read`, BRAM nunca responde
- Sin respuesta, waitrequest nunca baja
- **DEADLOCK**

---

## 🔍 VERIFICACIONES ADICIONALES

### Verificación 1: Estado de waitrequest

¿Qué debería hacer BRAM cuando no hay requests?
- Si no hay `avm_read = 1`, waitrequest debería ser 0 (disponible)
- Si waitrequest está en 1 sin requests, hay un problema de configuración

### Verificación 2: Orden de evaluación

¿Los defaults se ejecutan antes o después del case?
- En SystemVerilog, todas las asignaciones en `always_ff` se evalúan
- Los defaults se aplican, luego el case puede sobrescribirlos
- **Pero** si el case no asigna nada, los defaults prevalecen

### Verificación 3: Timing de señales

¿Hay problemas de timing?
- `read_req` es combinacional desde `seq_mem_rd_req`
- Si `seq_mem_rd_req` cambia mientras está en ARB_READ, `read_req` podría cambiar
- Esto podría afectar el comportamiento

---

## 📝 RESUMEN DEL PROBLEMA

**Síntoma:** PERF_READS = 0, busy nunca termina

**Causa Raíz:** El estado ARB_READ nunca emite `avm_read` porque:
- La condición `!avm_waitrequest && !avm_read` nunca se cumple
- `avm_waitrequest` está siempre en 1, O
- La lógica no mantiene `avm_read` activo correctamente

**Ubicación:** `rtl/DSA_Memory_Adapter.sv` líneas 265-287

**Solución necesaria:**
1. Cambiar la lógica de emisión de `avm_read` para que se mantenga activo
2. Manejar correctamente waitrequest
3. Asegurar que la lectura se emita al menos una vez

---

## 🎯 PRÓXIMOS PASOS

1. Verificar el valor de `avm_waitrequest` durante el bloqueo
2. Verificar que la dirección calculada sea correcta
3. Corregir la lógica del estado ARB_READ para mantener `avm_read` activo
4. Agregar timeout o retry mechanism si es necesario

