<!-- (C) 2025 - ntop.org     -->
<template>
  <div class="m-2 mb-3 mt-3 px-3">
    <Slider 
	v-model="timeline_value"
	:format="format"
	:min="timeline_min"
	:max="timeline_max"
	:step="timeline_step" 
	:disabled="disabled_date_picker"
        tooltipPosition="right"
        @change="onSliderChange"
    />
  </div>
</template>

<script>
import { ntopng_utility, ntopng_url_manager, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import Slider from '@vueform/slider'
import FormatterUtils from "../utilities/formatter-utils.js";

export default {
    components: {
        'Slider': Slider,
    },
    props: {
        id: String,
        min_epoch: Number,
        disabled_date_picker: Boolean,
    },
    computed: {
        // a computed getter
        invalid_date_message: function () {
            if (this.wrong_date) {
                return this.i18n('wrong_date_range');
            }
        }
    },
    watch: {
    },
    emits: [
        "epoch_change"
    ],

    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
        let min = this.$props.min_epoch;

        let today = FormatterUtils.get_midnight_epoch(this.get_utc_seconds(Date.now()));
        if (!min || FormatterUtils.get_midnight_epoch(min) == today) {
          let yesterday = FormatterUtils.get_midnight_epoch(today - this.timeline_step);
          min = yesterday; /* set begin time to yesterday at least */
        }

        this.setSliderMin(min);
    },

    beforeMount() {
    },

    /** This method is the first method called after html template creation. */
    mounted() {
        let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
        let epoch_end = ntopng_url_manager.get_url_entry("epoch_end");

        if (epoch_begin != null && epoch_end != null) {
            // update the status
            epoch_begin = Number.parseInt(epoch_begin);
            epoch_end = Number.parseInt(epoch_end);
            epoch_begin = FormatterUtils.get_midnight_epoch(epoch_begin); /* align to midnight */
            epoch_end = epoch_begin + this.timeline_step;

            this.emit_epoch_change({ epoch_begin: epoch_begin, epoch_end: epoch_end }, this.$props.id, true);
        }

        ntopng_events_manager.on_event_change(this.$props.id, ntopng_events.EPOCH_CHANGE, (new_status) => this.on_status_updated(new_status), true);

        // notifies that component is ready
        ntopng_sync.ready(this.$props["id"]);
    },

    /** Methods of the component. */
    methods: {
        onSliderChange(newValue) {
            let epoch_begin = newValue;
            let epoch_end = newValue + this.timeline_step;
            let epoch_status = { epoch_begin: epoch_begin, epoch_end: epoch_end };
            this.emit_epoch_change(epoch_status, this.$props.id);
            ntopng_url_manager.add_obj_to_url(epoch_status);
        },
        setSliderValue(val) {
          this.timeline_value = val;
        },
        setSliderMin(val) {
          this.timeline_min = FormatterUtils.get_midnight_epoch(val);
        },
        setSliderMax(val) {
          this.timeline_max = val;
        },
        on_status_updated: function (status) {
            let now = this.get_utc_seconds(Date.now());
            now = FormatterUtils.get_midnight_epoch(now);

            this.setSliderMax(now);

            if (status.epoch_end != null && status.epoch_begin != null
                && Number.parseInt(status.epoch_end) > Number.parseInt(status.epoch_begin)) {
                status.epoch_begin = Number.parseInt(status.epoch_begin);
                status.epoch_end = Number.parseInt(status.epoch_end);
            } else {
                // First iteration, set to Now
                let now = this.get_utc_seconds(Date.now());
                status.epoch_begin = now;
                status.epoch_end = now + this.timeline_step;

                ntopng_url_manager.add_obj_to_url(status);
                this.emit_epoch_change(status, this.$props.id);
            }

            this.setSliderValue(status.epoch_begin);

            ntopng_url_manager.add_obj_to_url({ epoch_begin: status.epoch_begin, epoch_end: status.epoch_end });
        },
        get_utc_seconds: function (utc_ms) {
            return ntopng_utility.get_utc_seconds(utc_ms);
        },
        emit_epoch_change: function (epoch_status, id, emit_only_global_event) {
            if (epoch_status.epoch_end == null || epoch_status.epoch_begin == null) { return; };
            if (id != this.id) {
                this.on_status_updated(epoch_status);
            }
            ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, epoch_status, this.id);
            if (emit_only_global_event) {
                return;
            }
            this.$emit("epoch_change", epoch_status);
        },
    },

    data: () => ({
        /* Private date of vue component */
        timeline_value: 0,
        timeline_min:   0,
        timeline_max:   0,
        timeline_step:  24*60*60, /* day */

        format: function (value) {
            let today = FormatterUtils.get_midnight_epoch(ntopng_utility.get_utc_seconds(Date.now()));
            if (value == today) return i18n("live");

            let str = FormatterUtils.formatDateTime(value, 'date_only');
            return str;
        },

        i18n: (t) => i18n(t),

        wrong_date: false,
    }),
}

</script>

<style scoped>
</style>
