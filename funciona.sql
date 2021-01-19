USE [MAXPOINT_V3.0]
GO
/****** Object:  StoredProcedure [config].[IAE_aplicaclientesformaspago]    Script Date: 19/1/2021 14:52:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
DESARROLLADO POR: Christian Pinto
DESCRIPCION: Trae los clientes para agregar en las formas de pago
TABLAS INVOLUCRADAS: Cliente, Formapago, Formapago_Atributos
FECHA CREACION: 22/08/2015
FECHA ULTIMA MODIFICACION: 29/01/2016
USUARIO QUE MODIFICO: Christian Pinto
DECRIPCION ULTIMO CAMBIO: Cambio de tablas de coleccion antiguas a nuevas
TABLAS INVOLUCRADAS: EstacionColeccionDeDatos, ColeccionDeDatosEstacion, ColeccionEstacion
*/
ALTER PROCEDURE [config].[IAE_aplicaclientesformaspago]
    @accion int,
	@idclientes VARCHAR(8000),
	@idusuario varchar(40),  
	@descripcionformapago varchar(200),
	@fmp_id varchar(40),
	@idcadena int
AS
BEGIN
	set nocount on;
	declare @cli_id varchar(40),@estado int, @ID_ColeccionDeDatosFormapago varchar(40), @ID_ColeccionFormapago varchar(40), @mdl_id int, @Descripcion varchar(200)

	IF (@accion = 1)
	BEGIN
	--EXEC config.IAE_aplicaclientesformaspago 1,'0,44,35',8,'DINERS',17, 10
		
		SET @ID_ColeccionFormapago = (select cast(ID_ColeccionFormapago as varchar(40)) from ColeccionFormapago where Descripcion = 'CLIENTES')
		SET @mdl_id = (select mdl_id from Modulo where mdl_descripcion = 'Formapago')
		SET @Descripcion = 'CLIENTES POR FORMA DE PAGO'	

					   declare CURSORITO cursor for 
							SELECT top(100) IDCliente, estado=0  FROM Cliente WHERE cast(IDCliente as varchar(40)) NOT IN (SELECT cast(Items as varchar(40)) AS Items FROM Split(@idclientes,',')) AND cast(IDCliente as varchar(40))<>'0' --revisar top(100) clientes
							UNION
							SELECT cast(Items as varchar(40)) AS cli_id, estado =1  FROM Split(@idclientes,',') WHERE  Items<>'0'
						open CURSORITO 

						fetch next from CURSORITO 
						into @cli_id,@estado
    						while @@fetch_status = 0 
      						  BEGIN

							  IF OBJECT_ID('tempdb..#i_seg_pantalla') IS NOT NULL BEGIN
									   DROP TABLE #i_seg_pantalla1;
								END ELSE BEGIN
									   CREATE TABLE #i_seg_pantalla1 (ID_ColeccionDeDatosFormapago VARCHAR(40)); --creamos tabla temporal para almacenar ultimo id
								END

									IF NOT EXISTS(SELECT * FROM FormapagoColeccionDeDatos WHERE variableV=@cli_id AND cast(IDFormapago as varchar(40))=@fmp_id)
										BEGIN
										INSERT INTO ColeccionDeDatosFormapago(Descripcion,tipodedato,isActive,lastUpdate,lastUser,intDescripcion,ID_ColeccionFormapago) 
											OUTPUT INSERTED.ID_ColeccionDeDatosFormapago INTO #i_seg_pantalla1 --insertamos el ultimo id insertado en la tabla temporal
										VALUES(@Descripcion,'i',1,GETDATE(),@idusuario,@cli_id,@ID_ColeccionFormapago)
								
										SET @ID_ColeccionDeDatosFormapago = (SELECT cast(ID_ColeccionDeDatosFormapago as varchar(40)) FROM  #i_seg_pantalla1); --almacenamos id de la tabla temporal
										
										 INSERT INTO FormapagoColeccionDeDatos(IDFormapago,ID_ColeccionDeDatosFormapago,variableV,variableB,ID_ColeccionFormapago,isActive,lastUpdate,lastUser,mdl_id)
										 VALUES(@fmp_id,@ID_ColeccionDeDatosFormapago, @cli_id, @estado, @ID_ColeccionFormapago,1,GETDATE(),@idusuario, @mdl_id)
											--AUDITORIA------------------------------------------
										
											IF(@estado=1)
											BEGIN
												DECLARE @descripcionupdate VARCHAR(200)
												SET @descripcionupdate= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Activo'
												EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdate,'MODIFICAR'

											END
											ELSE
											BEGIN
												DECLARE @descripcionupdatei VARCHAR(200)
												SET @descripcionupdatei= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Inactivo'
												EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdatei,'MODIFICAR'

											END
										
										
										------------------------------------------------------------

						
										END
									ELSE
										BEGIN

											--AUDITORIA------------------------------------------
			
										IF  EXISTS (SELECT * FROM FormapagoColeccionDeDatos WHERE variableV=@cli_id AND variableB <> @estado AND cast(IDFormapago as varchar(40))=@fmp_id)   
											BEGIN
												IF(@estado=1)
												BEGIN
												DECLARE @descripcionupdateactivo VARCHAR(200)
												SET @descripcionupdateactivo= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Activo'
												EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdateactivo,'MODIFICAR'

												END

												ELSE
												BEGIN
													DECLARE @descripcionupdateinactivo VARCHAR(200)
													SET @descripcionupdateinactivo= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Inactivo'
													EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdateinactivo,'MODIFICAR'

												END
										
										END 
										--select @estado,@cli_id,@fmp_id
											UPDATE FormapagoColeccionDeDatos
											SET
											    variableB = @estado,
												lastUpdate = GETDATE(),
												lastUser = @idusuario
											WHERE cast(IDFormapago as varchar(40))=@fmp_id AND variableV=@cli_id--SOLO CLIENTES SELECCIONADOS
									END

								 DROP TABLE #i_seg_pantalla1;
	    						 fetch next from CURSORITO 
       							 into @cli_id,@estado
        					  end 
						 close CURSORITO 
						 deallocate CURSORITO
	SET @accion=2		
	SELECT @accion AS AccionFormaPago--5,0 AS cli_id,0 AS cli_descripcion,0 AS agregado,0 AS rsat_bit	
	END
	
	IF @accion = 4
	BEGIN
		
		SET @ID_ColeccionFormapago = (select ID_ColeccionFormapago from ColeccionFormapago where Descripcion = 'CLIENTES')
		SET @mdl_id = (select mdl_id from Modulo where mdl_descripcion = 'Formapago')
		SET @Descripcion = 'CLIENTES POR FORMA DE PAGO'				
					   declare CURSORITO cursor for 
							SELECT top(100) IDCliente, estado=0  FROM Cliente WHERE cast(IDCliente as varchar(40)) NOT IN (SELECT cast(Items as varchar(40)) AS Items FROM Split(@idclientes,',')) AND cast(IDCliente as varchar(40))<>'0' --revisar top(100) clientes
							UNION
							SELECT cast(Items as varchar(40)) AS cli_id, estado =1  FROM Split(@idclientes,',') WHERE  Items<>'0'
						open CURSORITO 

						fetch next from CURSORITO 
						into @cli_id,@estado
    						while @@fetch_status = 0 
      						  BEGIN

							  IF OBJECT_ID('tempdb..#i_seg_pantalla') IS NOT NULL BEGIN
									   DROP TABLE #i_seg_pantalla;
								END ELSE BEGIN
									   CREATE TABLE #i_seg_pantalla (ID_ColeccionDeDatosFormapago VARCHAR(40)); --creamos tabla temporal para almacenar ultimo id
								END

									IF NOT EXISTS(SELECT * FROM FormapagoColeccionDeDatos WHERE variableV=@cli_id AND cast(IDFormapago as varchar(40))=@fmp_id)
										BEGIN
											
											 INSERT INTO ColeccionDeDatosFormapago(Descripcion,tipodedato,isActive,lastUpdate,lastUser,intDescripcion,ID_ColeccionFormapago) 
												OUTPUT INSERTED.ID_ColeccionDeDatosFormapago INTO #i_seg_pantalla --insertamos el ultimo id insertado en la tabla temporal
											 VALUES(@Descripcion,'i',1,GETDATE(),@idusuario,@cli_id,@ID_ColeccionFormapago)
								
											 SET @ID_ColeccionDeDatosFormapago = (SELECT cast(ID_ColeccionDeDatosFormapago as varchar(40)) FROM  #i_seg_pantalla); --almacenamos id de la tabla temporal

											  INSERT INTO FormapagoColeccionDeDatos(IDFormapago,ID_ColeccionDeDatosFormapago,variableV,variableB,ID_ColeccionFormapago,isActive,lastUpdate,lastUser,mdl_id)
												VALUES(@fmp_id,@ID_ColeccionDeDatosFormapago, @cli_id, @estado, @ID_ColeccionFormapago,1,GETDATE(),@idusuario, @mdl_id)
												--select @fmp_id,@ID_ColeccionDeDatosFormapago, @cli_id, @estado, @ID_ColeccionFormapago,1,GETDATE(),@idusuario, @mdl_id
											--AUDITORIA------------------------------------------
										
											IF(@estado=1)
											BEGIN
												--DECLARE @descripcionupdate VARCHAR(200)
												SET @descripcionupdate= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Activo'
												EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdate,'MODIFICAR'

											END
											ELSE
											BEGIN
												--DECLARE @descripcionupdatei VARCHAR(200)
												SET @descripcionupdatei= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Inactivo'
												EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdatei,'MODIFICAR'

											END
										
						
										------------------------------------------------------------

						
										END
									ELSE
										BEGIN

											--AUDITORIA------------------------------------------

											/*IF(@rst_id=1)
											BEGIN
												SELECT @rst_id, @estado, @idformapago
											END
											*/			
										IF  EXISTS (SELECT * FROM FormapagoColeccionDeDatos WHERE variableV=@cli_id AND variableB <> @estado AND cast(IDFormapago as varchar(40))=@fmp_id)
											BEGIN
												IF(@estado=1)
												BEGIN
												--DECLARE @descripcionupdateactivo VARCHAR(200)
												SET @descripcionupdateactivo= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Cliente: '+CAST(@cli_id AS varchar)+', '+'Estado: Activo'
												EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdateactivo,'MODIFICAR'

												END

												ELSE
												BEGIN
													--DECLARE @descripcionupdateinactivo VARCHAR(200)
													SET @descripcionupdateinactivo= 'Codigo Forma Pago: '+CAST(@fmp_id AS VARCHAR)+', '+'Descripcion: '+@descripcionformapago+','+'Aplica Codigo Restaurante: '+CAST(@cli_id AS varchar)+', '+'Estado: Inactivo'
													EXECUTE config.IAE_Audit_registro 'i', @idusuario,@idcadena,'FORMAS DE PAGO',@descripcionupdateinactivo,'MODIFICAR'

												END
										
										END 

											UPDATE FormapagoColeccionDeDatos
											SET
											    variableB = @estado, -- bit
												lastUpdate = GETDATE(),
												lastUser = @idusuario
											WHERE cast(IDFormapago as varchar(40))=@fmp_id AND variableV=@cli_id--SOLO CLIENTES SELECCIONADOS
									END
								 
								 DROP TABLE #i_seg_pantalla;
	    						 fetch next from CURSORITO 
       							 into @cli_id,@estado
        					  end 
						 close CURSORITO 
						 deallocate CURSORITO
	SET @accion=3		
	SELECT @accion AS AccionFormaPago--,0 AS rst_id,0 AS rst_descripcion,0 AS agregado,0 AS rsat_bit	
	END
END


