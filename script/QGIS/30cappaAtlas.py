"""
Model exported as python.
Name : 30cappaItaly
Group : 30cappa
With QGIS : 31602
"""

from qgis.core import QgsProcessing
from qgis.core import QgsProcessingAlgorithm
from qgis.core import QgsProcessingMultiStepFeedback
from qgis.core import QgsProcessingParameterVectorLayer
from qgis.core import QgsProcessingParameterFeatureSink
from qgis.core import QgsProcessingParameterBoolean
import processing


class Cappaitaly(QgsProcessingAlgorithm):

    def initAlgorithm(self, config=None):
        self.addParameter(QgsProcessingParameterVectorLayer('Vettorecomuni', 'Vettore Comuni con abitanti ISTAT gen20', types=[QgsProcessing.TypeVectorPolygon], defaultValue=None))
        self.addParameter(QgsProcessingParameterFeatureSink('Area30cappa', 'Area30cappa', type=QgsProcessing.TypeVectorAnyGeometry, createByDefault=True, supportsAppend=True, defaultValue=None))
        self.addParameter(QgsProcessingParameterBoolean('VERBOSE_LOG', 'Registrazione dettagliata', optional=True, defaultValue=False))

    def processAlgorithm(self, parameters, context, model_feedback):
        # Use a multi-step feedback, so that individual child algorithm progress reports are adjusted for the
        # overall progress through the model
        feedback = QgsProcessingMultiStepFeedback(8, model_feedback)
        results = {}
        outputs = {}

        # Capoluoghi (Estrai)
        alg_params = {
            'FIELD': 'CC_UTS',
            'INPUT': parameters['Vettorecomuni'],
            'OPERATOR': 1,
            'VALUE': '0',
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['CapoluoghiEstrai'] = processing.run('native:extractbyattribute', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(1)
        if feedback.isCanceled():
            return {}

        # Regioni (Dissolvi)
        alg_params = {
            'FIELD': [''],
            'INPUT': parameters['Vettorecomuni'],
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['RegioniDissolvi'] = processing.run('native:dissolve', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(2)
        if feedback.isCanceled():
            return {}

        # Vettore 5k (Estrai)
        alg_params = {
            'FIELD': 'Abitanti',
            'INPUT': parameters['Vettorecomuni'],
            'OPERATOR': 5,
            'VALUE': '5000',
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['Vettore5kEstrai'] = processing.run('native:extractbyattribute', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(3)
        if feedback.isCanceled():
            return {}

        # Buffer
        alg_params = {
            'DISSOLVE': False,
            'DISTANCE': 30000,
            'END_CAP_STYLE': 0,
            'INPUT': outputs['Vettore5kEstrai']['OUTPUT'],
            'JOIN_STYLE': 0,
            'MITER_LIMIT': 2,
            'SEGMENTS': 10,
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['Buffer'] = processing.run('native:buffer', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(4)
        if feedback.isCanceled():
            return {}

        # Differenza
        alg_params = {
            'INPUT': outputs['Buffer']['OUTPUT'],
            'OVERLAY': outputs['CapoluoghiEstrai']['OUTPUT'],
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['Differenza'] = processing.run('native:difference', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(5)
        if feedback.isCanceled():
            return {}

        # Intersezione
        alg_params = {
            'INPUT': outputs['Differenza']['OUTPUT'],
            'INPUT_FIELDS': [''],
            'OVERLAY': outputs['RegioniDissolvi']['OUTPUT'],
            'OVERLAY_FIELDS': [''],
            'OVERLAY_FIELDS_PREFIX': '',
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['Intersezione'] = processing.run('native:intersection', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(6)
        if feedback.isCanceled():
            return {}

        # Riorganizzazione campi
        alg_params = {
            'FIELDS_MAPPING': [{'expression': '\"COD_RIP\"','length': 1,'name': 'COD_RIP','precision': 0,'type': 2},{'expression': '\"COD_REG\"','length': 2,'name': 'COD_REG','precision': 0,'type': 2},{'expression': '\"COD_PROV\"','length': 3,'name': 'COD_PROV','precision': 0,'type': 2},{'expression': '\"COD_CM\"','length': 3,'name': 'COD_CM','precision': 0,'type': 2},{'expression': '\"COD_UTS\"','length': 3,'name': 'COD_UTS','precision': 0,'type': 2},{'expression': '\"PRO_COM\"','length': 6,'name': 'PRO_COM','precision': 0,'type': 2},{'expression': '\"PRO_COM_T\"','length': 6,'name': 'PRO_COM_T','precision': 0,'type': 10},{'expression': '\"COMUNE\"','length': 34,'name': 'COMUNE','precision': 0,'type': 10},{'expression': '\"COMUNE_A\"','length': 36,'name': 'COMUNE_A','precision': 0,'type': 10},{'expression': '\"CC_UTS\"','length': 1,'name': 'CC_UTS','precision': 0,'type': 2},{'expression': '\"Abitanti\"','length': 7,'name': 'Abitanti','precision': 0,'type': 2}],
            'INPUT': outputs['Intersezione']['OUTPUT'],
            'OUTPUT': parameters['Area30cappa']
        }
        outputs['RiorganizzazioneCampi'] = processing.run('native:refactorfields', alg_params, context=context, feedback=feedback, is_child_algorithm=True)
        results['Area30cappa'] = outputs['RiorganizzazioneCampi']['OUTPUT']

        feedback.setCurrentStep(7)
        if feedback.isCanceled():
            return {}

        # Imposta codifica layer
        alg_params = {
            'ENCODING': 'UTF-8',
            'INPUT': outputs['RiorganizzazioneCampi']['OUTPUT']
        }
        outputs['ImpostaCodificaLayer'] = processing.run('native:setlayerencoding', alg_params, context=context, feedback=feedback, is_child_algorithm=True)
        return results

    def name(self):
        return '30cappaItaly'

    def displayName(self):
        return '30cappaItaly'

    def group(self):
        return '30cappa'

    def groupId(self):
        return '30cappa'

    def createInstance(self):
        return Cappaitaly()
