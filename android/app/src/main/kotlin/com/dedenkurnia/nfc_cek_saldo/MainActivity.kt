package com.dedenkurnia.nfc_cek_saldo

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.nfc.tech.MifareClassic
import android.nfc.tech.MifareUltralight
import android.nfc.tech.Ndef
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.dedenkurnia.nfc_cek_saldo/nfc"

        // Daftar Key A yang dicoba — default + yang terdokumentasi publik
        private val KEYS_A: List<ByteArray> = listOf(
            hex("FFFFFFFFFFFF"),  // default blank
            hex("A0A1A2A3A4A5"),  // MAD Key A
            hex("D3F7D3F7D3F7"),  // NDEF
            hex("000000000000"),  // all zero
            hex("B0B1B2B3B4B5"),
            hex("4D3A99C351DD"),
            hex("1A982C7E459A"),
            hex("AABBCCDDEEFF"),
            hex("714C5C886E97"),
            hex("587EE5F9350F"),
            hex("A0478CC39091"),
            hex("533CB6C723F6"),
            hex("8FD0A4F256E9"),
        )
        private val KEYS_B: List<ByteArray> = listOf(
            hex("FFFFFFFFFFFF"),
            hex("B0B1B2B3B4B5"),
            hex("000000000000"),
            hex("AABBCCDDEEFF"),
        )

        private fun hex(s: String): ByteArray =
            s.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

        private fun ByteArray.toHexStr(): String =
            joinToString("") { "%02X".format(it) }
    }

    private var nfcAdapter: NfcAdapter? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val a = nfcAdapter
                        result.success(
                            mapOf(
                                "available" to (a != null),
                                "enabled" to (a?.isEnabled == true)
                            )
                        )
                    }
                    "startScan" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Sedang scanning", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        enableForegroundDispatch()
                    }
                    "stopScan" -> {
                        disableForegroundDispatch()
                        pendingResult?.error("CANCELLED", "Dibatalkan", null)
                        pendingResult = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableForegroundDispatch() {
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        nfcAdapter?.enableForegroundDispatch(this, pi, null, null)
    }

    private fun disableForegroundDispatch() {
        try {
            nfcAdapter?.disableForegroundDispatch(this)
        } catch (_: Exception) {}
    }

    override fun onPause() {
        super.onPause()
        disableForegroundDispatch()
    }

    override fun onResume() {
        super.onResume()
        if (pendingResult != null) enableForegroundDispatch()
    }

    @Suppress("DEPRECATION")
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.action ?: return
        if (action != NfcAdapter.ACTION_TECH_DISCOVERED &&
            action != NfcAdapter.ACTION_TAG_DISCOVERED &&
            action != NfcAdapter.ACTION_NDEF_DISCOVERED
        ) return

        val tag: Tag? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }

        if (tag == null) return
        disableForegroundDispatch()
        Thread { processTag(tag) }.start()
    }

    // ──────────────────────────────────────────────────────────────────────────

    private fun processTag(tag: Tag) {
        val out = mutableMapOf<String, Any?>()
        try {
            out["uid"] = tag.id.toHexStr()
            out["techList"] = tag.techList.toList()

            val rawData = mutableListOf<String>()
            var balance: Long? = null

            when {
                MifareClassic.get(tag) != null -> {
                    out["type"] = "MIFARE Classic"
                    balance = readMifareClassic(tag, rawData)
                }
                MifareUltralight.get(tag) != null -> {
                    out["type"] = "MIFARE Ultralight"
                    balance = readMifareUltralight(tag, rawData)
                }
                IsoDep.get(tag) != null -> {
                    out["type"] = "ISO-DEP / Chip"
                    balance = readIsoDep(tag, rawData)
                }
                else -> {
                    out["type"] = "NFC Tag"
                    readNdef(tag, rawData)
                }
            }

            out["balance"] = balance
            out["rawData"] = rawData
            out["success"] = true

        } catch (e: Exception) {
            out["success"] = false
            out["error"] = e.message ?: "Error tidak diketahui"
        }

        runOnUiThread {
            pendingResult?.success(out)
            pendingResult = null
        }
    }

    // ── MIFARE Classic ────────────────────────────────────────────────────────

    private fun readMifareClassic(tag: Tag, rawData: MutableList<String>): Long? {
        val mc = MifareClassic.get(tag) ?: return null
        var balance: Long? = null

        mc.connect()
        try {
            for (sector in 0 until mc.sectorCount) {
                var authed = false

                for (key in KEYS_A) {
                    if (safeTry { mc.authenticateSectorWithKeyA(sector, key) } == true) {
                        rawData.add("S$sector ✓ KeyA:${key.toHexStr()}")
                        authed = true
                        break
                    }
                }
                if (!authed) {
                    for (key in KEYS_B) {
                        if (safeTry { mc.authenticateSectorWithKeyB(sector, key) } == true) {
                            rawData.add("S$sector ✓ KeyB:${key.toHexStr()}")
                            authed = true
                            break
                        }
                    }
                }
                if (!authed) {
                    rawData.add("S$sector ✗ key tidak cocok")
                    continue
                }

                val firstBlock = mc.sectorToBlock(sector)
                val blockCount = mc.getBlockCountInSector(sector)
                for (i in 0 until blockCount - 1) {
                    val data = safeTry { mc.readBlock(firstBlock + i) } ?: continue
                    rawData.add("S${sector}B${i}: ${data.toHexStr()}")

                    if (balance == null) {
                        balance = tryValueBlock(data) ?: tryLittleEndian(data) ?: tryBigEndian(data)
                    }
                }
            }
        } finally {
            safeTry { mc.close() }
        }
        return balance
    }

    // MIFARE Value Block: [val LE 4][~val 4][val LE 4][addr][~addr][addr][~addr]
    private fun tryValueBlock(d: ByteArray): Long? {
        if (d.size < 12) return null
        val v1 = d.le4(0)
        val v2 = d.le4(4)
        val v3 = d.le4(8)
        if (v1 == v3 && (v1 xor v2) == 0xFFFFFFFFL) {
            if (v1 in 100..9_999_999) return v1
        }
        return null
    }

    private fun tryLittleEndian(d: ByteArray): Long? {
        if (d.size < 4) return null
        val v = d.le4(0)
        return if (v in 500..9_999_999) v else null
    }

    private fun tryBigEndian(d: ByteArray): Long? {
        if (d.size < 4) return null
        val v = ((d[0].toLong() and 0xFF) shl 24) or
                ((d[1].toLong() and 0xFF) shl 16) or
                ((d[2].toLong() and 0xFF) shl 8) or
                (d[3].toLong() and 0xFF)
        return if (v in 500..9_999_999) v else null
    }

    private fun ByteArray.le4(offset: Int): Long =
        ((this[offset + 3].toLong() and 0xFF) shl 24) or
        ((this[offset + 2].toLong() and 0xFF) shl 16) or
        ((this[offset + 1].toLong() and 0xFF) shl 8) or
        (this[offset].toLong() and 0xFF)

    // ── MIFARE Ultralight ─────────────────────────────────────────────────────

    private fun readMifareUltralight(tag: Tag, rawData: MutableList<String>): Long? {
        val ul = MifareUltralight.get(tag) ?: return null
        var balance: Long? = null
        ul.connect()
        try {
            for (page in 4..15) {
                val data = safeTry { ul.readPages(page) } ?: break
                val chunk = data.take(4).toByteArray()
                rawData.add("P$page: ${chunk.toHexStr()}")
                if (balance == null) balance = tryLittleEndian(chunk)
            }
        } finally {
            safeTry { ul.close() }
        }
        return balance
    }

    // ── ISO-DEP (chip EMV) ────────────────────────────────────────────────────

    private fun readIsoDep(tag: Tag, rawData: MutableList<String>): Long? {
        val dep = IsoDep.get(tag) ?: return null
        dep.connect()
        try {
            // SELECT PPSE
            val ppse = safeTry {
                dep.transceive(hex("00A404000E325041592E5359532E444446303100"))
            }
            if (ppse != null) rawData.add("PPSE: ${ppse.toHexStr()}")
        } finally {
            safeTry { dep.close() }
        }
        return null
    }

    // ── NDEF ──────────────────────────────────────────────────────────────────

    private fun readNdef(tag: Tag, rawData: MutableList<String>) {
        val ndef = Ndef.get(tag) ?: return
        ndef.connect()
        try {
            val msg = ndef.cachedNdefMessage ?: ndef.ndefMessage ?: return
            msg.records.forEach { r ->
                rawData.add("NDEF: ${r.payload.toHexStr()}")
            }
        } finally {
            safeTry { ndef.close() }
        }
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private fun <T> safeTry(block: () -> T): T? = try { block() } catch (_: Exception) { null }
}
